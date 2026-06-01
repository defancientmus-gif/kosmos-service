const modeLabels = {
  repair: "Ремонт",
  preorder: "Предзаказ техники",
  business: "Корпоративная заявка",
};

const modeHints = {
  repair: "Поломка / симптом",
  preorder: "Что подобрать",
  business: "Задача компании",
};

const form = document.querySelector("#lead-form");
const output = document.querySelector("#lead-output");
const copyButton = document.querySelector("#copy-request");
const details = form.elements.details;

function getFormData() {
  const data = new FormData(form);
  return {
    mode: data.get("mode"),
    name: String(data.get("name") || "").trim(),
    contact: String(data.get("contact") || "").trim(),
    device: String(data.get("device") || "").trim(),
    urgency: String(data.get("urgency") || "").trim(),
    details: String(data.get("details") || "").trim(),
  };
}

function buildMessage() {
  const data = getFormData();
  const label = modeLabels[data.mode] || "Заявка";
  const body = [
    `Новая заявка: ${label}`,
    "",
    `Имя: ${data.name || "не указано"}`,
    `Контакт: ${data.contact || "не указан"}`,
    `Устройство: ${data.device || "не указано"}`,
    `Срочность: ${data.urgency || "не указана"}`,
    `${modeHints[data.mode] || "Описание"}: ${data.details || "не указано"}`,
    "",
    "Источник: сайт КОсмос сервис",
  ];

  return body.join("\n");
}

function renderMessage() {
  output.textContent = buildMessage();
}

form.addEventListener("change", (event) => {
  if (event.target.name === "mode") {
    details.placeholder =
      event.target.value === "preorder"
        ? "Модель, бюджет, новая или б/у техника, желаемый срок."
        : event.target.value === "business"
          ? "Сколько устройств, какая задача, нужен ли договор/отчёт."
          : "Опишите поломку, симптомы и что уже пробовали.";
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
    }, 1600);
  } catch {
    copyButton.textContent = "Выделите текст вручную";
    window.setTimeout(() => {
      copyButton.textContent = "Скопировать";
    }, 2200);
  }
});

renderMessage();
