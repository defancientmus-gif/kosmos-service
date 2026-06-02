const modeLabels = {
  repair: "Ремонт",
  preorder: "Подбор / предзаказ техники",
  digital: "Цифровая помощь",
  business: "Корпоративная задача",
};

const modeHints = {
  repair: "Что случилось",
  preorder: "Что подобрать",
  digital: "Где нужна помощь",
  business: "Что нужно компании",
};

const form = document.querySelector("#lead-form");
const output = document.querySelector("#lead-output");
const copyButton = document.querySelector("#copy-request");
const details = form.elements.details;
const heroVideo = document.querySelector(".hero-video");

function getFormData() {
  const data = new FormData(form);

  return {
    mode: String(data.get("mode") || "repair"),
    contact: String(data.get("contact") || "").trim(),
    device: String(data.get("device") || "").trim(),
    details: String(data.get("details") || "").trim(),
  };
}

function buildMessage() {
  const data = getFormData();

  return [
    `Новая заявка: ${modeLabels[data.mode] || "Задача"}`,
    "",
    `${modeHints[data.mode] || "Описание"}: ${data.details || "не указано"}`,
    `Устройство: ${data.device || "не указано"}`,
    `Контакт: ${data.contact || "не указан"}`,
    "",
    "Источник: сайт Космос Сервис",
  ].join("\n");
}

function updatePlaceholder(mode) {
  const placeholders = {
    repair: "Например: телефон не заряжается, разбит экран, быстро садится батарея.",
    preorder: "Модель, бюджет, новая или б/у техника, желаемый срок.",
    digital: "Не могу войти, не понимаю уведомление, нужно перенести данные, настроить аккаунт.",
    business: "Сколько устройств, какая задача, нужен ли договор/отчёт.",
  };

  details.placeholder = placeholders[mode] || placeholders.repair;
}

function renderMessage() {
  output.textContent = buildMessage();
}

form.addEventListener("change", (event) => {
  if (event.target.name === "mode") {
    updatePlaceholder(event.target.value);
  }

  renderMessage();
});

form.addEventListener("input", renderMessage);

form.addEventListener("submit", (event) => {
  event.preventDefault();
  renderMessage();
});

copyButton.addEventListener("click", async () => {
  renderMessage();

  try {
    await navigator.clipboard.writeText(output.textContent);
    copyButton.textContent = "Скопировано";
    window.setTimeout(() => {
      copyButton.textContent = "Скопировать";
    }, 1500);
  } catch {
    copyButton.textContent = "Выделите текст";
    window.setTimeout(() => {
      copyButton.textContent = "Скопировать";
    }, 2000);
  }
});

updatePlaceholder("repair");
renderMessage();

if (heroVideo) {
  heroVideo.muted = true;
  heroVideo.play().catch(() => {
    heroVideo.controls = true;
  });
}
