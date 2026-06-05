import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const DEFAULT_ALLOWED_ORIGINS = [
  "http://127.0.0.1:5050",
  "http://localhost:5050",
  "http://127.0.0.1:8000",
  "http://localhost:8000",
];

const ALLOWED_GITHUB_PREFIXES = [
  "texts/agent-notes/",
  "texts/backlog/",
  "texts/prompts/",
  "data/templates/",
];

const BLOCKED_GITHUB_PREFIXES = [
  ".env",
  "_inbox/",
  "_archive/",
  "data/live/",
  "private/",
  "secrets/",
  "Документы Космос/",
  "Загрузки Космос/",
];

type JsonRecord = Record<string, unknown>;

type AuthedContext = {
  supabase: ReturnType<typeof createClient>;
  user: { id: string; email?: string };
};

function allowedOrigins() {
  const configured = Deno.env.get("KOSMOS_ALLOWED_ORIGINS");
  if (!configured) return DEFAULT_ALLOWED_ORIGINS;
  return configured.split(",").map((origin) => origin.trim()).filter(Boolean);
}

function corsHeaders(req: Request) {
  const requestOrigin = req.headers.get("origin") || "";
  const origins = allowedOrigins();
  const allowOrigin = origins.includes("*")
    ? "*"
    : origins.includes(requestOrigin)
    ? requestOrigin
    : origins[0] || DEFAULT_ALLOWED_ORIGINS[0];

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Headers": "authorization, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
}

function json(req: Request, status: number, body: JsonRecord) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders(req),
      "Content-Type": "application/json; charset=utf-8",
    },
  });
}

function normalizeGitHubPath(rawPath: unknown) {
  if (typeof rawPath !== "string") {
    throw new Error("path must be a string");
  }

  const path = rawPath.replaceAll("\\", "/").replace(/^\/+/, "");
  if (!path || path.includes("..") || path.endsWith("/")) {
    throw new Error("path is not allowed");
  }

  if (BLOCKED_GITHUB_PREFIXES.some((prefix) => path === prefix || path.startsWith(prefix))) {
    throw new Error("path is blocked");
  }

  if (!ALLOWED_GITHUB_PREFIXES.some((prefix) => path.startsWith(prefix))) {
    throw new Error("path is outside allowed agent write areas");
  }

  return path;
}

function base64Encode(input: string) {
  const bytes = new TextEncoder().encode(input);
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}

async function requireUser(req: Request): Promise<AuthedContext> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Response(
      JSON.stringify({ error: "Supabase function environment is not configured" }),
      { status: 500 },
    );
  }

  const authorization = req.headers.get("authorization") || "";
  const token = authorization.replace(/^Bearer\s+/i, "").trim();
  if (!token) {
    throw new Response(JSON.stringify({ error: "Missing Authorization bearer token" }), {
      status: 401,
    });
  }

  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    throw new Response(JSON.stringify({ error: "Invalid or expired session" }), {
      status: 401,
    });
  }

  return {
    supabase,
    user: { id: data.user.id, email: data.user.email ?? undefined },
  };
}

async function parseBody(req: Request) {
  try {
    return await req.json();
  } catch {
    throw new Response(JSON.stringify({ error: "Request body must be JSON" }), {
      status: 400,
    });
  }
}

async function logAction(
  ctx: AuthedContext,
  actionType: string,
  status: string,
  input: JsonRecord,
  result: JsonRecord = {},
) {
  const { error } = await ctx.supabase.from("agent_actions").insert({
    user_id: ctx.user.id,
    action_type: actionType,
    status,
    input,
    result,
    requires_confirmation: status !== "done",
    executed_at: status === "done" ? new Date().toISOString() : null,
  });

  if (error) {
    console.error("agent_actions insert failed", error.message);
  }
}

async function runAiDraft(ctx: AuthedContext, body: JsonRecord) {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    return { configured: false, error: "AI provider secret is not configured" };
  }

  const prompt = typeof body.prompt === "string" ? body.prompt.trim() : "";
  if (!prompt) {
    return { error: "prompt is required" };
  }

  const model = Deno.env.get("ANTHROPIC_MODEL") || Deno.env.get("KOSMOS_AI_MODEL") ||
    "claude-sonnet-4-5";

  const response = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model,
      max_tokens: 1200,
      system:
        "Ты операционный помощник Космос Сервиса. Помогай с CRM, документами, оплатами и рутиной. Не принимай налоговые и финансовые решения без подтверждения владельца.",
      messages: [{ role: "user", content: prompt.slice(0, 12000) }],
    }),
  });

  if (!response.ok) {
    const details = await response.text();
    console.error("Anthropic request failed", response.status, details.slice(0, 500));
    return { error: "AI provider request failed", status: response.status };
  }

  const payload = await response.json();
  const text = Array.isArray(payload.content)
    ? payload.content
      .filter((item: JsonRecord) => item.type === "text" && typeof item.text === "string")
      .map((item: JsonRecord) => item.text)
      .join("\n")
    : "";

  await logAction(ctx, "ai_draft", "done", { prompt: prompt.slice(0, 500) }, { model });
  return { configured: true, model, text };
}

async function writeGitHub(ctx: AuthedContext, body: JsonRecord) {
  const token = Deno.env.get("GITHUB_TOKEN");
  const repo = Deno.env.get("GITHUB_REPO");
  if (!token || !repo) {
    return { configured: false, error: "GitHub secrets are not configured" };
  }

  const path = normalizeGitHubPath(body.path);
  const content = typeof body.content === "string" ? body.content : "";
  if (!content.trim()) {
    return { error: "content is required" };
  }

  if (content.length > 200_000) {
    return { error: "content is too large for agent GitHub write" };
  }

  const apiUrl = `https://api.github.com/repos/${repo}/contents/${encodeURIComponent(path).replaceAll("%2F", "/")}`;
  const getResponse = await fetch(apiUrl, {
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "X-GitHub-Api-Version": "2022-11-28",
    },
  });

  let sha: string | undefined;
  if (getResponse.ok) {
    const existing = await getResponse.json();
    sha = typeof existing.sha === "string" ? existing.sha : undefined;
  } else if (getResponse.status !== 404) {
    console.error("GitHub read failed", getResponse.status, await getResponse.text());
    return { error: "GitHub read failed", status: getResponse.status };
  }

  const putResponse = await fetch(apiUrl, {
    method: "PUT",
    headers: {
      "Accept": "application/vnd.github+json",
      "Authorization": `Bearer ${token}`,
      "Content-Type": "application/json",
      "X-GitHub-Api-Version": "2022-11-28",
    },
    body: JSON.stringify({
      message: `[agent] Update ${path}`,
      content: base64Encode(content),
      sha,
      committer: {
        name: "Kosmos Agent",
        email: "agent@kosmos.local",
      },
    }),
  });

  if (!putResponse.ok) {
    console.error("GitHub write failed", putResponse.status, await putResponse.text());
    return { error: "GitHub write failed", status: putResponse.status };
  }

  const payload = await putResponse.json();
  const result = {
    configured: true,
    path,
    commit_sha: payload.commit?.sha,
    html_url: payload.content?.html_url,
  };
  await logAction(ctx, "github_write", "done", { path }, result);
  return result;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders(req) });
  }

  if (req.method !== "POST") {
    return json(req, 405, { error: "Method not allowed" });
  }

  try {
    const ctx = await requireUser(req);
    const body = await parseBody(req);
    const action = typeof body.action === "string" ? body.action : "health";

    if (action === "health") {
      return json(req, 200, {
        ok: true,
        user_id: ctx.user.id,
        features: {
          ai: Boolean(Deno.env.get("ANTHROPIC_API_KEY")),
          github: Boolean(Deno.env.get("GITHUB_TOKEN") && Deno.env.get("GITHUB_REPO")),
        },
      });
    }

    if (action === "log-action") {
      await logAction(ctx, "manual_log", "done", body);
      return json(req, 200, { ok: true });
    }

    if (action === "ai-draft") {
      const result = await runAiDraft(ctx, body);
      return json(req, result.error ? 400 : 200, result);
    }

    if (action === "github-write") {
      const result = await writeGitHub(ctx, body);
      return json(req, result.error ? 400 : 200, result);
    }

    return json(req, 400, { error: "Unknown action" });
  } catch (error) {
    if (error instanceof Response) {
      const status = error.status || 500;
      const body = await error.text();
      return new Response(body, {
        status,
        headers: {
          ...corsHeaders(req),
          "Content-Type": "application/json; charset=utf-8",
        },
      });
    }

    console.error(error);
    return json(req, 500, { error: "Internal server error" });
  }
});
