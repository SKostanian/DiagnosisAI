/**
 Hello! I am Spartak G21067972
 and here is my core logic of the VertexAI chat in app.

 I have used many sources, (included in comments, with Bibguru help: https://app.bibguru.com/).
 */

import {setGlobalOptions} from "firebase-functions/v2";
import {onRequest, onCall} from "firebase-functions/v2/https";
import {HttpsError} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import {getFirestore, FieldValue} from "firebase-admin/firestore";
import {VertexAI} from "@google-cloud/vertexai";

// I got it from here:
// (2025) Stackoverflow.com. Available at: https://stackoverflow.com/questions/79734470/firebase-cloud-functions-return-internal-error-with-no-logs-after-moving-proje (Accessed: March 12, 2026).
setGlobalOptions({region: "us-central1", maxInstances: 10});
// Add the Firebase Admin SDK to your server (2026) Firebase. Available at: https://firebase.google.com/docs/admin/setup (Accessed: March 12, 2026).
admin.initializeApp();
const db = getFirestore();

// Structured output (2026) Google Cloud Documentation.
// Available at: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/multimodal/control-generated-output (Accessed: March 12, 2026).

// Vertex Config
const RUNTIME_PROJECT =
  process.env.GCLOUD_PROJECT ||
  process.env.GOOGLE_CLOUD_PROJECT ||

  // Firebase-admin.App package (2026) Firebase. Available at: https://firebase.google.com/docs/reference/admin/node/firebase-admin.app.md (Accessed: March 12, 2026).
  (admin.app().options.projectId as string | undefined) || // TypeScript union types (2026) W3schools.com. Available at: https://www.w3schools.com/typescript/typescript_union_types.php (Accessed: March 12, 2026).
  (process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG).projectId : undefined);

// Function calling reference (no date) Google Cloud Documentation.
// Available at: https://docs.cloud.google.com/vertex-ai/generative-ai/docs/model-reference/function-calling (Accessed: March 12, 2026).
const PROJECT_ID = RUNTIME_PROJECT as string | undefined;
const LOCATION = process.env.VERTEX_LOCATION || "us-central1";
const MODEL_ID = process.env.VERTEX_MODEL || "gemini-2.5-flash-lite";
if (!PROJECT_ID) {
    // Write and view logs (2026) Firebase. Available at: https://firebase.google.com/docs/functions/writing-and-viewing-logs (Accessed: March 12, 2026).
    logger.error("Vertex: no projectId");
}

const vertexAI = new VertexAI({project: PROJECT_ID ?? "", location: LOCATION});

// Get started with the Gemini API using the Firebase AI Logic SDKs (2026) Firebase.
// Available at: https://firebase.google.com/docs/ai-logic/get-started?api=dev (Accessed: March 12, 2026).
const generativeModel = vertexAI.getGenerativeModel({
  model: MODEL_ID,
  generationConfig: {responseMimeType: "application/json"},
});

// Here I have config show, in case
logger.info("Vertex config is: ", {project: PROJECT_ID, location: LOCATION, model: MODEL_ID});

/* Schemas */
// I have 2 schemas, for question and diagnosis

const QUESTION_SCHEMA = {
  type: "object",
  properties: {
    id: {type: "string"},
    text: {type: "string"},
    type: {type: "string", enum: ["text", "single", "multi", "number", "scale"]},
    options: {type: "array", items: {type: "string"}},
    unit: {type: "string"},
    topic: {type: "string"},
  },
  required: ["id", "text", "type", "topic"],
} as const;
const DIAGNOSIS_SCHEMA = {
  type: "object",
  properties: {
    type: {type: "string", enum: ["diagnosis"]},
    dx: { // array of diagnoses
      type: "array",
      minItems: 1,
      maxItems: 5,
      items: {
        type: "object",
        properties: {
          code: {type: "string"}, // I have medical code format, like ICD10 for example
          system: {type: "string", enum: ["ICD10", "SNOMED"]},
          label: {type: "string"}, // diagnosis name

          prob: {type: "number", minimum: 0, maximum: 1}, // probability from 0 to 1 of diagnosis
        },
        required: ["code", "system", "label", "prob"],
      },
    },
    confidence: {type: "number", minimum: 0, maximum: 1}, // confidence

    redFlags: {type: "array", items: {type: "string"}},
    explanation_patient: {type: "string"},
    summary_clinician: {type: "string"},
    actions_now: {type: "array", items: {type: "string"}},
    seek_care_if: {type: "array", items: {type: "string"}},
  },
  required: ["type", "dx", "confidence", "explanation_patient", "summary_clinician"],
};

// normalizing and checking duplications
const SKIP_VALUE = "__duplicate_client_skip__";
function normalizeText(s: string): string {
    // Unicode character class escape: \p{...}, \P{...} (no date) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Regular_expressions/Unicode_character_class_escape (Accessed: March 12, 2026).
    // delete all the punctuation, spaces, leave inly L letters, N numbers and 1 space
  return (s || "").toLowerCase().replace(/[^\p{L}\p{N}\s]/gu, " ").replace(/\s+/g, " ").trim();
}

// I have function to classify the keywords in generated questions to each category
function canonicalQuestionKey(text: string): string | null {
  const t = normalizeText(text);
  if (/(where|which side|location|где|какая часть|какая половина|локализ)/.test(t)) return "location";
  if (/(quality|what does it feel|character|характер|как .* (болит|ощущается)|пульсир|колющ|туп|жгуч)/.test(t)) return "quality";
  if (/(severity|scale|0 ?- ?10|1 ?to ?10|от ?1 ?до ?10|шкал[ае])/.test(t)) return "severity";
  if (/(how long|since when|duration|onset|как давно|сколько времени|когда началось|с какого)/.test(t)) return "duration";
  if (/(nausea|vomit|vomiting|тошнот|рвот|photophobia|phonophobia|неврол|weakness|numb|speech|vision)/.test(t)) return "associated";
  if (/(trigger|worse|better|что помогает|что усиливает|что ухудша|провоцир)/.test(t)) return "triggers";
  return null;
}

// Wikipedia contributors (2025) Jaccard index, Wikipedia, The Free Encyclopedia. Available at: https://en.wikipedia.org/w/index.php?title=Jaccard_index&oldid=1311865137.
// Jaccard similarity between 2 texts based on shared words

function jaccardSimilarity(a: string, b: string): number {
  // Set - JavaScript (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Set (Accessed: March 12, 2026).

  // Array.Prototype.Filter() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/filter (Accessed: March 12, 2026).
  const A = new Set(normalizeText(a).split(" ").filter((w) => w.length > 2));
  const B = new Set(normalizeText(b).split(" ").filter((w) => w.length > 2));

  if (A.size === 0 || B.size === 0) return 0;
  // I have intersection as in formula, the shared words, we count it
  let inter = 0; for (const w of A) if (B.has(w)) inter++;

  // Spread syntax (...) (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Spread_syntax (Accessed: March 12, 2026).
  const union = new Set([...A, ...B]).size;
  return inter / union;
}

// if a new text is semantically similar to any previously asked text
// no flase positives if higher theshold
function isSemanticallyDuplicate(text: string, askedTexts: string[], threshold = 0.7): boolean {

    // Array.Prototype.Some() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/some (Accessed: March 12, 2026).
  return askedTexts.some((prev) => jaccardSimilarity(text, prev) >= threshold);
}

function normalizeLocaleTag(locale: string): string {

    // by default eng
    // BCP 47 language tag (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Glossary/BCP_47_language_tag (Accessed: March 12, 2026).
  const lc = (locale || "en").toLowerCase();

  // String.Prototype.startsWith() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/startsWith (Accessed: March 12, 2026).
  if (lc.startsWith("ru")) return "ru-RU"; // WHY STARTSWITH, PAPER
  if (lc.startsWith("el")) return "el-GR";
  return "en-US";
}

// helpers
function listInline(items: string[]) {
    // to show array like * shortness of breath * cough etc.
  return items.join(" * ");
}

function normalizeNumericValue(v: any, clamp0to10 = true) {
  if (typeof v === "number") {
      // normalize value from 0 to 10
    const n = Math.round(v);
    return clamp0to10 ? Math.max(0, Math.min(10, n)) : n;
  }
  if (typeof v === "string") {
      // search for num in a text

      // Regular expression syntax cheat sheet (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Regular_expressions/Cheatsheet (Accessed: March 12, 2026).
    const m = v.match(/-?\d+(?:[.,]\d+)?/);
    if (m) {

        // ParseFloat() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/parseFloat (Accessed: March 12, 2026).
      const n = Math.round(parseFloat(m[0].replace(",", "."))); // I replace because js/ts only understands .
      return clamp0to10 ? Math.max(0, Math.min(10, n)) : n;
    }
    return v.trim();
  }
  return v;
}

// normalization of diagnoses
function normalizeDx(diag: any, areas?: string[]) {
    // extract the array of diagnoses if present, ir use an empty array
  let items: any[] = Array.isArray(diag?.dx) ? diag.dx : [];

  // fallback if llm empty, if no diagnises
  if (items.length === 0) {
    const allowed = allowedDxForAreas(areas || []) || [];
    const fallback = allowed.slice(0, 3).map((d) => ({
      ...d,
      // dqual prob for each fallback diagnoses
      prob: 1 / Math.min(3, allowed.length || 1),
    }));
    items = fallback;
  }

  // normalization
  items = items.map((d: any) => ({
    ...d,

    // each diagnoses from 1 to 0
    // Number.isFinite() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/isFinite (Accessed: March 12, 2026).
    prob: Number.isFinite(d?.prob) ? Math.max(0, Math.min(1, Number(d.prob))) : 0,
  }));

    // Array.Prototype.Reduce() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/reduce (Accessed: March 12, 2026).
  let sum = items.reduce((s, d) => s + d.prob, 0);

  if (sum <= 0) {
    const p = 1 / items.length;
    items = items.map((d) => ({...d, prob: p}));
    sum = 1;
  }

  items = items.map((d) => {
    const norm = d.prob / sum;
    return {...d, prob: norm, pct: toPct(norm)};
  });

  items.sort((a, b) => (b?.prob ?? 0) - (a?.prob ?? 0));
  const confidence = Number.isFinite(diag?.confidence) ?
    diag.confidence :
    (items[0]?.prob ?? 0);

  return {...diag, dx: items, confidence};
}

// I have completed 3 main body areas: chest, head and back. In future I add for other areas too
// check which body area was selected
function areaCategory(areas: string[]): "chest" | "head" | "back" | "default" {
  const s = areas.join(" ").toLowerCase();
  if (/(chest|thorax|rib|ribs|breath|lung|resp|pleur|груд|дых)/.test(s)) return "chest";
  if (/(head|face|temple|forehead|occiput|migraine)/.test(s)) return "head";
  if (/(back|spine|lumbar|thoracic|sciatic|lower_back|upper_back)/.test(s)) return "back";
  return "default";
}

// gives list of possible associated symptoms, depends on area
function associatedOptions(tag: string, areas: string[]): string[] {
  const cat = areaCategory(areas);
  if (tag === "ru-RU") {
    if (cat === "chest") {
      return [
        "Одышка при нагрузке", "Одышка в покое", "Удушье", "Сухой кашель", "Кашель с мокротой", "Кашель с кровью",
        "Температура", "Озноб", "Боль при глубоком вдохе", "Боль при кашле", "Хрипы/свисты при дыхании",
        "Учащённое сердцебиение", "Нерегулярный пульс", "Боль в левой руке", "Боль в челюсти/шее",
        "Холодный пот", "Потливость", "Тошнота", "Головокружение", "Слабость", "Беспокойство/тревога",
        "Синюшность губ/пальцев", "Отёки ног", "Боль в спине", "Изжога", "Затруднённое глотание",
      ];
    }
    if (cat === "head") return ["Светобоязнь", "Шумобоязнь", "Тошнота", "Рвота", "Нарушение зрения", "Нарушение речи", "Слабость/онемение", "Температура"];
    if (cat === "back") return ["Иррадиация в ногу", "Онемение/покалывание", "Слабость в ноге", "Нарушение мочеиспускания", "Температура"];
    return ["Температура", "Тошнота", "Рвота", "Слабость", "Головокружение"];
  } else {
    if (cat === "chest") {
      return [
        "Shortness of breath on exertion", "Shortness of breath at rest", "Feeling of suffocation", "Dry cough", "Productive cough", "Cough with blood",
        "Fever", "Chills", "Pain on deep breathing", "Pain when coughing", "Wheezing/whistling sounds",
        "Rapid heartbeat", "Irregular pulse", "Left arm pain", "Jaw/neck pain",
        "Cold sweats", "Sweating", "Nausea", "Dizziness", "Weakness", "Anxiety/restlessness",
        "Blue lips/fingers", "Leg swelling", "Back pain", "Heartburn", "Difficulty swallowing",
      ];
    }
    if (cat === "head") return ["Photophobia", "Phonophobia", "Nausea", "Vomiting", "Vision change", "Speech trouble", "Weakness/numbness", "Fever"];
    if (cat === "back") return ["Radiation to leg", "Numbness/tingling", "Leg weakness", "Urinary problems", "Fever"];
    return ["Fever", "Nausea", "Vomiting", "Weakness", "Dizziness"];
  }
}

// options for describing pain quality. they both in russian and english, I will add greek in future
function qualityOptions(tag: string): string[] {
  return tag === "ru-RU" ?
    ["Пульсирующая", "Давящая", "Колющая", "Жгучая", "Тупая", "Стреляющая"] :
    ["Pulsating", "Pressing", "Stabbing", "Burning", "Dull", "Shooting"];
}

// small helper for severity text
function severityText(tag: string): string {
  return tag === "ru-RU" ?
    "Оцените боль по шкале 1–10." :
    "Rate your pain 1–10.";
}

// very first question about feeling/pain
function buildFirstTurnFeeling(tag: string, areas: string[]) {
  return {
    id: "feeling",
    text: tag === "ru-RU" ? "Вы ощущаете боль? Что вы чувствуете в этой области?" : "Do you feel pain? What do you feel in this body region?",
    type: "single",
    options: tag === "ru-RU" ?
      ["Боль", "Давление/тяжесть", "Дискомфорт", "Покалывание/онемение"] :
      ["Pain", "Pressure/heaviness", "Discomfort", "Tingling/numbness"],
    unit: undefined,
    topic: "feeling",
  };
}

// very first question about pain quality (used after feeling if Pain selected)
function buildFirstTurnQuality(tag: string) {
  return {
    id: "quality",
    text: tag === "ru-RU" ? "Какая у вас боль?" : "What does the pain feel like?",
    type: "single",
    options: qualityOptions(tag),
    unit: undefined,
    topic: "quality",
  };
}

// I have extended diagnosis dictionary for chest region with anamnesis consideration

// RISKS ARE EXPERIMENTAL, DO NOT USE IN REAL CLINIC ENVIRONMENT.
// Yes they are correct but THEY DO NOT COVER ALL of the risks for each illness
const DX_VOCAB = {
  chest: [
    // Infectious diseases
    {
      labelRU: "Внебольничная пневмония",
      labelEN: "Community-acquired pneumonia",
      system: "ICD10", code: "J18.9",
      riskFactorsRU: ["возраст >65", "курение", "хронические заболевания"],
      riskFactorsEN: ["age >65", "smoking", "chronic diseases"],
    },
    {
      labelRU: "Госпитальная пневмония",
      labelEN: "Hospital-acquired pneumonia",
      system: "ICD10", code: "J18.8",
      riskFactorsRU: ["недавняя госпитализация", "иммунодефицит"],
      riskFactorsEN: ["recent hospitalization", "immunodeficiency"],
    },
    {
      labelRU: "Острый бронхит",
      labelEN: "Acute bronchitis",
      system: "ICD10", code: "J20.9",
      riskFactorsRU: ["курение", "ХОБЛ в анамнезе"],
      riskFactorsEN: ["smoking", "COPD history"],
    },
    {
      labelRU: "Обострение ХОБЛ",
      labelEN: "COPD exacerbation",
      system: "ICD10", code: "J44.1",
      riskFactorsRU: ["длительное курение", "пожилой возраст"],
      riskFactorsEN: ["long-term smoking", "older age"],
    },
    {
      labelRU: "Обострение астмы",
      labelEN: "Asthma exacerbation",
      system: "ICD10", code: "J45.901",
      riskFactorsRU: ["астма в анамнезе", "аллергены", "стресс"],
      riskFactorsEN: ["asthma history", "allergens", "stress"],
    },

    // Cardiovascular diseases
    {
      labelRU: "Острый коронарный синдром",
      labelEN: "Acute coronary syndrome",
      system: "ICD10", code: "I24.9",
      riskFactorsRU: ["пожилой возраст", "курение", "диабет", "гипертензия", "семейный анамнез ИБС"],
      riskFactorsEN: ["older age", "smoking", "diabetes", "hypertension", "family history CAD"],
    },
    {
      labelRU: "Нестабильная стенокардия",
      labelEN: "Unstable angina",
      system: "ICD10", code: "I20.0",
      riskFactorsRU: ["ИБС в анамнезе", "факторы риска ИБС"],
      riskFactorsEN: ["CAD history", "CAD risk factors"],
    },
    {
      labelRU: "Острый перикардит",
      labelEN: "Acute pericarditis",
      system: "ICD10", code: "I30.9",
      riskFactorsRU: ["вирусная инфекция", "аутоиммунные заболевания"],
      riskFactorsEN: ["viral infection", "autoimmune diseases"],
    },
    {
      labelRU: "Тахиаритмия",
      labelEN: "Tachyarrhythmia",
      system: "ICD10", code: "I47.9",
      riskFactorsRU: ["заболевания сердца", "гипертиреоз", "кофеин"],
      riskFactorsEN: ["heart disease", "hyperthyroidism", "caffeine"],
    },
    {
      labelRU: "Сердечная недостаточность",
      labelEN: "Heart failure",
      system: "ICD10", code: "I50.9",
      riskFactorsRU: ["ИБС", "гипертензия", "возраст", "диабет"],
      riskFactorsEN: ["CAD", "hypertension", "age", "diabetes"],
    },

    // Thromboembolic diseases
    {
      labelRU: "ТЭЛА (тромбоэмболия лёгочной артерии)",
      labelEN: "Pulmonary embolism",
      system: "ICD10", code: "I26.9",
      riskFactorsRU: ["операции", "иммобилизация", "контрацептивы", "онкология", "беременность"],
      riskFactorsEN: ["surgery", "immobilization", "contraceptives", "cancer", "pregnancy"],
    },
    {
      labelRU: "Тромбоз глубоких вен",
      labelEN: "Deep vein thrombosis",
      system: "ICD10", code: "I80.9",
      riskFactorsRU: ["те же, что для ТЭЛА"],
      riskFactorsEN: ["same as for PE"],
    },

    // Pleural diseases
    {
      labelRU: "Плеврит",
      labelEN: "Pleuritis",
      system: "ICD10", code: "R09.1",
      riskFactorsRU: ["инфекции", "онкология", "аутоиммунные заболевания"],
      riskFactorsEN: ["infections", "cancer", "autoimmune diseases"],
    },
    {
      labelRU: "Пневмоторакс спонтанный",
      labelEN: "Spontaneous pneumothorax",
      system: "ICD10", code: "J93.9",
      riskFactorsRU: ["молодой возраст", "высокий рост", "курение"],
      riskFactorsEN: ["young age", "tall stature", "smoking"],
    },
    {
      labelRU: "Пневмоторакс травматический",
      labelEN: "Traumatic pneumothorax",
      system: "ICD10", code: "S27.0",
      riskFactorsRU: ["травма грудной клетки"],
      riskFactorsEN: ["chest trauma"],
    },

    // Gastrointestinal causes
    {
      labelRU: "ГЭРБ/эзофагит",
      labelEN: "GERD/esophagitis",
      system: "ICD10", code: "K21.9",
      riskFactorsRU: ["ожирение", "курение", "алкоголь", "острая пища"],
      riskFactorsEN: ["obesity", "smoking", "alcohol", "spicy food"],
    },
    {
      labelRU: "Язвенная болезнь с пенетрацией",
      labelEN: "Penetrating peptic ulcer",
      system: "ICD10", code: "K25.5",
      riskFactorsRU: ["H. pylori", "НПВС", "курение"],
      riskFactorsEN: ["H. pylori", "NSAIDs", "smoking"],
    },

    // Musculoskeletal causes
    {
      labelRU: "Костохондрит",
      labelEN: "Costochondritis",
      system: "ICD10", code: "M94.0",
      riskFactorsRU: ["физические нагрузки", "травма"],
      riskFactorsEN: ["physical exertion", "trauma"],
    },
    {
      labelRU: "Межрёберная невралгия",
      labelEN: "Intercostal neuralgia",
      system: "ICD10", code: "M79.2",
      riskFactorsRU: ["опоясывающий лишай", "травма"],
      riskFactorsEN: ["herpes zoster", "trauma"],
    },
    {
      labelRU: "Миозит/миалгия грудной клетки",
      labelEN: "Chest wall myositis/myalgia",
      system: "ICD10", code: "M79.1",
      riskFactorsRU: ["физические нагрузки", "вирусная инфекция"],
      riskFactorsEN: ["physical exertion", "viral infection"],
    },
    {
      labelRU: "Перелом ребра",
      labelEN: "Rib fracture",
      system: "ICD10", code: "S22.4",
      riskFactorsRU: ["травма", "остеопороз", "возраст"],
      riskFactorsEN: ["trauma", "osteoporosis", "age"],
    },

    // Neurological and psychiatric
    {
      labelRU: "Опоясывающий лишай",
      labelEN: "Herpes zoster",
      system: "ICD10", code: "B02.9",
      riskFactorsRU: ["возраст >50", "иммунодефицит", "стресс"],
      riskFactorsEN: ["age >50", "immunodeficiency", "stress"],
    },
    {
      labelRU: "Тревожное расстройство/панические атаки",
      labelEN: "Anxiety disorder/panic attacks",
      system: "ICD10", code: "F41.0",
      riskFactorsRU: ["молодой возраст", "стресс"],
      riskFactorsEN: ["young age", "stress"],
    },

    // Oncological
    {
      labelRU: "Рак лёгкого",
      labelEN: "Lung cancer",
      system: "ICD10", code: "C78.0",
      riskFactorsRU: ["курение", "возраст >50", "семейный анамнез", "профвредности"],
      riskFactorsEN: ["smoking", "age >50", "family history", "occupational hazards"],
    },
    {
      labelRU: "Метастатическое поражение лёгких",
      labelEN: "Pulmonary metastases",
      system: "ICD10", code: "C78.0",
      riskFactorsRU: ["онкология в анамнезе"],
      riskFactorsEN: ["cancer history"],
    },
  ],
};

function allowedDxForAreas(areas: string[]) {
  const s = areas.join(" ").toLowerCase();
  if (/(chest|thorax|rib|ribs|breath|lung|resp|pleur|груд|дых)/.test(s)) return DX_VOCAB.chest;
  return null;
}

// must ask questions //chest specific
const MUST_ASK_BY_AREA = {
  chest: [
    // Basic symptom questions
    {
      id: "onset_nature", topic: "duration",
      textRU: "Как начались симптомы?",
      textEN: "How did the symptoms start?",
      type: "single" as const,
      optionsRU: ["Внезапно", "Постепенно"],
      optionsEN: ["Suddenly", "Gradually"],
    },
    {
      id: "pleuritic", topic: "associated",
      textRU: "Боль усиливается при глубоком вдохе или кашле?",
      textEN: "Does the pain get worse when you breathe deeply or cough?",
      type: "single" as const,
      optionsRU: ["Да", "Нет"], optionsEN: ["Yes", "No"],
    },
    {
      id: "radiation", topic: "associated",
      textRU: "Куда распространяется боль?",
      textEN: "Where does the pain radiate to?",
      type: "multi" as const,
      optionsRU: ["Нет распространения", "Левая рука", "Правая рука", "Челюсть/шея", "Спина"],
      optionsEN: ["No radiation", "Left arm", "Right arm", "Jaw/neck", "Back"],
    },
    {
      id: "exertion_relation", topic: "triggers",
      textRU: "Связана ли боль с физической нагрузкой?",
      textEN: "Is the pain related to physical activity?",
      type: "single" as const,
      optionsRU: ["Да, хуже при нагрузке", "Нет", "Не уверен"],
      optionsEN: ["Yes—worse on exertion", "No", "Unsure"],
    },
    {
      id: "relief_rest", topic: "triggers",
      textRU: "Уменьшается ли боль в покое или после нитроглицерина?",
      textEN: "Does the pain improve with rest or nitroglycerin?",
      type: "single" as const,
      optionsRU: ["Да", "Нет", "Не пробовал"],
      optionsEN: ["Yes", "No", "Not tried"],
      skipIf: {dependsOn: "exertion_relation", values: ["Нет", "No"]},
    },
    {
      id: "positional", topic: "triggers",
      textRU: "Становится ли хуже лёжа и лучше сидя?",
      textEN: "Is it worse when lying flat and better when sitting up?",
      type: "single" as const,
      optionsRU: ["Да", "Нет"], optionsEN: ["Yes", "No"],
    },
    {
      id: "palpation_tenderness", topic: "associated",
      textRU: "Боль усиливается при надавливании на грудную клетку?",
      textEN: "Is the area tender when pressed (chest wall)?",
      type: "single" as const,
      optionsRU: ["Да", "Нет"], optionsEN: ["Yes", "No"],
    },
    {
      id: "cough_type", topic: "associated",
      textRU: "Какой у вас кашель?",
      textEN: "What kind of cough do you have?",
      type: "single" as const,
      optionsRU: ["Нет кашля", "Сухой кашель", "Кашель с мокротой", "Кашель с кровью"],
      optionsEN: ["No cough", "Dry cough", "Productive cough", "Cough with blood"],
    },
    {
      id: "cough_duration", topic: "duration",
      textRU: "Сколько длится кашель?",
      textEN: "How long have you had the cough?",
      type: "single" as const,
      optionsRU: ["<3 дней", "3–7 дней", ">1 недели", ">3 недель"],
      optionsEN: ["<3 days", "3–7 days", ">1 week", ">3 weeks"],
      skipIf: {dependsOn: "cough_type", values: ["Нет кашля", "No cough"]},
    },
    {
      id: "sputum_color", topic: "associated",
      textRU: "Какого цвета мокрота?",
      textEN: "What color is your sputum when you cough?",
      type: "single" as const,
      optionsRU: ["Прозрачная", "Белая/серая", "Жёлтая/зелёная", "С кровью"],
      optionsEN: ["Clear", "White/gray", "Yellow/green", "Bloody"],
      skipIf: {dependsOn: "cough_type", values: ["Нет кашля", "Сухой кашель", "No cough", "Dry cough"]},
    },
    {
      id: "dyspnea_type", topic: "associated",
      textRU: "Какая у вас одышка?",
      textEN: "What type of shortness of breath do you have?",
      type: "single" as const,
      optionsRU: ["Нет одышки", "Только при нагрузке", "В покое", "Приступы удушья"],
      optionsEN: ["No shortness of breath", "Only during physical activity", "Even when resting", "Episodes where I feel like I can't breathe"],
    },

    // Extended history and demographics
    {
      id: "age_group", topic: "demographics",
      textRU: "Ваш возраст?",
      textEN: "What is your age group?",
      type: "single" as const,
      optionsRU: ["18-30 лет", "31-50 лет", "51-65 лет", "Старше 65 лет"],
      optionsEN: ["18-30 years old", "31-50 years old", "51-65 years old", "Over 65 years old"],
    },

    // Smoking and harmful habits
    {
      id: "smoking_history", topic: "risk_factors",
      textRU: "Ваш статус курения?",
      textEN: "What is your smoking status?",
      type: "single" as const,
      optionsRU: ["Никогда не курил", "Бросил курить", "Курю <1 пачки/день", "Курю ≥1 пачки/день"],
      optionsEN: ["I have never smoked", "I used to smoke but quit", "I smoke less than 1 pack per day", "I smoke 1 pack or more per day"],
    },
    {
      id: "smoking_duration", topic: "risk_factors",
      textRU: "Стаж курения?",
      textEN: "How long have you been smoking?",
      type: "single" as const,
      optionsRU: ["<5 лет", "5-10 лет", "10-20 лет", ">20 лет"],
      optionsEN: ["Less than 5 years", "5-10 years", "10-20 years", "More than 20 years"],
      skipIf: {dependsOn: "smoking_history", values: ["Никогда не курил", "I have never smoked"]},
    },

    // Chronic diseases
    {
      id: "chronic_conditions", topic: "medical_history",
      textRU: "Есть хронические заболевания?",
      textEN: "Do you have any chronic medical conditions?",
      type: "multi" as const,
      optionsRU: ["Нет", "Астма", "ХОБЛ", "ИБС/стенокардия", "Артериальная гипертензия", "Сахарный диабет", "Онкология", "Заболевания лёгких"],
      optionsEN: ["None", "Asthma", "COPD", "CAD/angina", "Hypertension", "Diabetes", "Cancer history", "Lung disease"],
    },
    {
      id: "heart_disease_details", topic: "medical_history",
      textRU: "Есть ли у вас сердечно-сосудистые заболевания?",
      textEN: "Do you have any heart conditions?",
      type: "multi" as const,
      optionsRU: ["Нет", "Инфаркт миокарда в анамнезе", "Стентирование/шунтирование", "Аритмии", "Сердечная недостаточность"],
      optionsEN: ["No", "Previous heart attack", "Heart stents or bypass surgery", "Irregular heart rhythm", "Heart failure"],
    },

    // Medication history
    {
      id: "medications", topic: "medications",
      textRU: "Какие лекарства принимаете?",
      textEN: "What medications are you currently taking?",
      type: "multi" as const,
      optionsRU: ["Не принимаю", "Антикоагулянты/антиагреганты", "Гормональные контрацептивы", "Бета-блокаторы", "Ингаляторы", "Статины", "Мочегонные"],
      optionsEN: ["None", "Anticoagulants/antiplatelets", "Hormonal contraceptives", "Beta-blockers", "Inhalers", "Statins", "Diuretics"],
    },

    // Pulmonary embolism risk factors
    {
      id: "pe_risk_factors", topic: "risk_factors",
      textRU: "Факторы риска тромбоэмболии?",
      textEN: "Do you have any risk factors for blood clots in the lungs?",
      type: "multi" as const,
      optionsRU: ["Нет", "Операция в последние 4 недели", "Длительная иммобилизация", "Перелом ноги", "Длительный перелёт", "Беременность/роды", "Варикозная болезнь"],
      optionsEN: ["None", "Surgery in last 4 weeks", "Prolonged immobilization", "Leg fracture", "Long flight", "Pregnancy/childbirth", "Varicose veins"],
    },

    // Family history
    {
      id: "family_history", topic: "family_history",
      textRU: "Семейный анамнез?",
      textEN: "Is there any relevant family medical history?",
      type: "multi" as const,
      optionsRU: ["Нет значимого", "ИБС у родственников <60 лет", "Внезапная сердечная смерть", "Тромбозы у родственников", "Рак лёгких"],
      optionsEN: ["None significant", "CAD in relatives <60y", "Sudden cardiac death", "Thrombosis in relatives", "Lung cancer"],
    },

    // Additional symptoms
    {
      id: "fever_pattern", topic: "associated",
      textRU: "Характер лихорадки?",
      textEN: "Do you have any fever, and if so, what kind?",
      type: "single" as const,
      optionsRU: ["Нет температуры", "Субфебрильная (37-38°C)", "Фебрильная (38-39°C)", "Высокая (>39°C)", "С ознобом"],
      optionsEN: ["No fever", "Low-grade (37-38°C)", "Moderate (38-39°C)", "High (More than 39°C)", "With chills"],
    },
    {
      id: "fever_degree", topic: "associated",
      textRU: "Какая была максимальная температура?",
      textEN: "What was the highest temperature?",
      type: "single" as const,
      optionsRU: ["<37.5°C", "37.5–38°C", "38–39°C", ">39°C"],
      optionsEN: ["<99.5°F", "99.5–100.4°F", "100.4–102.2°F", ">102.2°F"],
      skipIf: {dependsOn: "fever_pattern", values: ["Нет температуры", "No fever"]},
    },
    {
      id: "cardiac_symptoms", topic: "associated",
      textRU: "Сердечные симптомы?",
      textEN: "Are you experiencing any heart-related symptoms?",
      type: "multi" as const,
      optionsRU: ["Нет", "Сердцебиение", "Перебои в сердце", "Боль в левой руке", "Боль в челюсти", "Холодный пот", "Обмороки"],
      optionsEN: ["None", "Palpitations", "Irregular heartbeat", "Left arm pain", "Jaw pain", "Cold sweats", "Syncope"],
    },
    {
      id: "gi_symptoms", topic: "associated",
      textRU: "ЖКТ симптомы?",
      textEN: "Do you have any stomach or digestive symptoms?",
      type: "multi" as const,
      optionsRU: ["Нет", "Изжога", "Тошнота", "Рвота", "Затруднённое глотание", "Боль после еды", "Отрыжка"],
      optionsEN: ["None", "Heartburn", "Nausea", "Vomiting", "Difficulty swallowing", "Pain after eating", "Belching"],
    },
  ],
};

// I compute chest priority order based on feeling by user
function chestPriorityOrder(feel: string | undefined): string[] | null {
  if (!feel || typeof feel !== "string") return null;
  const f = feel.toLowerCase();

  // RegExp.Prototype.Test() (2025) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/test (Accessed: March 12, 2026).
  const isPain = /pain|боль/.test(f);
  const isPressure = /pressure|heaviness|давлен|тяжест/.test(f);
  const isTingle = /tingl|numb|покалыв|онемен/.test(f);
  const isDiscomfort = /discomfort|дискомфорт/.test(f);

  // there are 4 feelings what I use

  if (isPain) {
    return [
      "quality", "severity", "exertion_relation", "relief_rest", "radiation", "pleuritic", "positional", "palpation_tenderness",
      "dyspnea_type", "cough_type", "cough_duration", "sputum_color", "fever_pattern", "fever_degree",
      "age_group", "smoking_history", "smoking_duration", "chronic_conditions", "heart_disease_details", "medications", "pe_risk_factors", "family_history",
      "onset_nature", "gi_symptoms",
    ];
  }
  if (isPressure) {
    return [
      "exertion_relation", "relief_rest", "severity", "radiation", "dyspnea_type", "positional", "palpation_tenderness", "quality",
      "cough_type", "cough_duration", "sputum_color", "fever_pattern", "fever_degree",
      "age_group", "smoking_history", "smoking_duration", "chronic_conditions", "heart_disease_details", "medications", "pe_risk_factors", "family_history",
      "onset_nature", "gi_symptoms",
    ];
  }
  if (isTingle) {
    return [
      "palpation_tenderness", "positional", "severity", "dyspnea_type",
      "cough_type", "cough_duration", "sputum_color", "radiation", "pleuritic", "fever_pattern", "fever_degree",
      "age_group", "smoking_history", "smoking_duration", "chronic_conditions", "heart_disease_details", "medications", "pe_risk_factors", "family_history",
      "onset_nature", "gi_symptoms", "quality",
    ];
  }
  if (isDiscomfort) {
    return [
      "quality", "severity", "radiation", "dyspnea_type", "exertion_relation", "pleuritic", "positional", "palpation_tenderness",
      "cough_type", "cough_duration", "sputum_color", "fever_pattern", "fever_degree",
      "age_group", "smoking_history", "smoking_duration", "chronic_conditions", "heart_disease_details", "medications", "pe_risk_factors", "family_history",
      "onset_nature", "gi_symptoms",
    ];
  }
  return null;
}

// pick next must ask question // chest
function nextMustAsk(
  tag: string,
  areas: string[],
  answers: Record<string, any>,
  answeredCount: number
) {
  const s = areas.join(" ").toLowerCase();
  const isChest = /(chest|thorax|rib|ribs|breath|lung|resp|pleur|груд|дых)/.test(s);
  if (!isChest) return null;
  if (answeredCount < 2) return null;

  // Array.Prototype.Slice() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/slice (Accessed: March 12, 2026).
  const list = MUST_ASK_BY_AREA.chest.slice();

  // reorder by priority
  const feel = answers?.["feeling"] as string | undefined;
  const priority = chestPriorityOrder(feel);
  if (priority) {
    const weight = new Map<string, number>();
    priority.forEach((id, idx) => weight.set(id, idx));

    // here are getters
    // Map.Prototype.Get() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Map/get (Accessed: March 12, 2026).
    list.sort((a, b) => (weight.get(a.id) ?? 9999) - (weight.get(b.id) ?? 9999));
  }

  for (const q of list) {
    if (q.id in answers) continue; // already answered

    // I skip if dependency says so
    if (q.skipIf && q.skipIf.dependsOn && answers[q.skipIf.dependsOn]) {
      const answer = answers[q.skipIf.dependsOn];
      if (
        Array.isArray(q.skipIf.values) &&
        (Array.isArray(answer) ? answer : [answer]).some((a) => q.skipIf.values.includes(a))
      ) {
        continue;
      }
    }

    // here we return first must ask question not yet answered
    return {
      id: q.id,
      text: tag === "ru-RU" ? q.textRU : q.textEN,
      type: q.type,
      options: tag === "ru-RU" ? q.optionsRU : q.optionsEN,
      topic: q.topic,
    };
  }
  return null;
}

// here is funciton to finalize question object before sending to client
function sanitizeQuestion(
  q: any,
  tag: string,
  selectedAreas: string[],
  askedTopics: string[],
) {
  // if topic missing, guess from text
  if (!q?.topic || typeof q.topic !== "string" || !q.topic.trim()) {

      // I use misc, from miscallenous, when 1st condition doesnot meet
    q.topic = canonicalQuestionKey(q?.text ?? "") ?? "misc";
  }

  // if it’s first turn and question is weird, force ask pain quality
  if (askedTopics.length === 0 && (q.topic === "location" || q.topic === "misc")) {
    q = buildFirstTurnQuality(tag);
  }

  // if topic is pain quality, add options
  if (q.topic === "quality") {
    q.type = "single";
    q.options = qualityOptions(tag);
    q.text = tag === "ru-RU" ?
      `Как вы описываете боль? (варианты: ${listInline(q.options)})` :
      `How would you describe the pain? (options: ${listInline(q.options)})`;
  }

  // if severity, force scale 1-10
  if (q.topic === "severity") {
    q.type = "scale";
    q.unit = "1-10";
    q.text = severityText(tag);
  }

  // if associated symptoms, provide choices
  if (q.topic === "associated") {
    const opts = associatedOptions(tag, selectedAreas);
    q.type = "multi";
    q.options = opts;
    q.text = tag === "ru-RU" ?
      `Выберите сопутствующие симптомы (можно несколько): ${listInline(opts)}` :
      `Select accompanying symptoms (you can pick multiple): ${listInline(opts)}`;
  }

  // if triggers I give standard opts
  if (q.topic === "triggers") {
    const opts = tag === "ru-RU" ?
      ["Движение", "Покой", "Свет", "Шум", "Стресс", "Другое"] :
      ["Movement", "Rest", "Light", "Noise", "Stress"];
    q.type = "multi";
    q.options = opts;
    q.text = tag === "ru-RU" ?
      `Что усиливает или облегчает боль? ${listInline(opts)}` :
      `What worsens or relieves pain? ${listInline(opts)}`;
  }

  // fallback options if missing
  if ((q.type === "single" || q.type === "multi") && (!Array.isArray(q.options) || q.options.length === 0)) {
    q.options = q.topic === "quality" ?
      qualityOptions(tag) :
      (tag === "ru-RU" ? ["Да", "Нет"] : ["Yes", "No"]);
  }

  if ((q.type === "number" || q.type === "scale") && !q.unit) q.unit = "1-10";

  // question need to have id
  if (!q.id || typeof q.id !== "string" || !q.id.trim()) q.id = q.topic || "q";

  return q;
}

// Helperб determine if a question should be skipped based on existing answers
function shouldSkipQuestion(q: any, answers: Record<string, any>, tag: string): boolean {
  const text = (q?.text || "").toString();

  // skip smoking duration if user never smoked
  const neverSmokedEN = "I have never smoked";
  const neverSmokedRU = "Никогда не курил";
  const smokingStatus = answers?.["smoking_history"];
  const saidNever = Array.isArray(smokingStatus) ?
    smokingStatus.includes(neverSmokedEN) || smokingStatus.includes(neverSmokedRU) :
    (smokingStatus === neverSmokedEN || smokingStatus === neverSmokedRU);
  const isSmokingDurationId = q?.id === "smoking_duration";
  const isSmokingDurationText = /how long have you been smoking|стаж курения/i.test(text);
  if (saidNever && (isSmokingDurationId || isSmokingDurationText)) return true;

  // if sputum color already known, I skip any sputum color question
  const hasSputumColor = Object.prototype.hasOwnProperty.call(answers, "sputum_color");
  if (hasSputumColor) {
    const idStr = (q?.id || "").toString();
    const isSputumColorId = idStr === "sputum_color" || /sputum.*color|color.*sputum/i.test(idStr);
    const textLc = text.toLowerCase();
    const isSputumColorText = /(sputum|phlegm).*color|цвет.*мокрот/.test(textLc);
    if (isSputumColorId || isSputumColorText) return true;
  }

  return false;
}

// I have fallback question function, based on priorities, what missing
function nextFallbackQuestion(
  tag: string,
  selectedAreas: string[],
  answers: Record<string, any>,
  askedTopics: string[]
) {
  const missing = new Set(["feeling", "quality", "severity", "duration", "associated", "triggers"]);
  for (const t of askedTopics) missing.delete(t);

  // if pain feeling is missing entirely, ask feeling first
  if (missing.has("feeling")) {
    return buildFirstTurnFeeling(tag, selectedAreas);
  }

  // if user indicated pain but no quality, ask quality
  const feel = answers["feeling"];
  const saidPain = typeof feel === "string" && /pain|боль/i.test(feel);
  if (saidPain && missing.has("quality")) {
    return buildFirstTurnQuality(tag);
  }
  if (missing.has("severity")) {
    return {id: "severity", topic: "severity", type: "scale", unit: "1-10", text: severityText(tag), options: []};
  }
  if (missing.has("duration")) {
    return {id: "duration", topic: "duration", type: "text", text: tag === "ru-RU" ? "Как давно это началось?" : "How long has this been going on?", options: []};
  }
  if (missing.has("associated")) {
    const opts = associatedOptions(tag, selectedAreas);
    return {id: "associated", topic: "associated", type: "multi", options: opts, text: tag === "ru-RU" ? `Выберите сопутствующие симптомы (можно несколько): ${listInline(opts)}` : `Select accompanying symptoms (you can pick multiple): ${listInline(opts)}`};
  }
  if (missing.has("triggers")) {
    const opts = tag === "ru-RU" ? ["Движение", "Покой", "Свет", "Шум", "Стресс", "Другое"] : ["Movement", "Rest", "Light", "Noise", "Stress"];
    return {id: "triggers", topic: "triggers", type: "multi", options: opts, text: tag === "ru-RU" ? `Что усиливает или облегчает боль? ${listInline(opts)}` : `What worsens or relieves pain? ${listInline(opts)}`};
  }
  return null;
}

// probability
function toPct(n: number): number {
  if (!Number.isFinite(n)) return 0;
  return Math.max(0, Math.min(100, Math.round(n * 100)));
}

/* Prompts */
function buildQuestionPrompt(
  locale: string,
  selectedAreas: string[],
  answers: Record<string, any>,
  askedTopics: string[],
  questionsLeft: number
) {
  const tag = normalizeLocaleTag(locale);

// I have this prompt for Vertex AI questions
  return `
You are a warm, friendly, and empathetic health assistant.
Your goal is to gather the patient's key symptoms in a gentle and supportive manner.

Ask ONE question at a time, then STOP.
Keep your tone short, clear, and patient-friendly.
Write in "${tag}".
Use BUTTON-LIKE responses where appropriate to make answering easier.

Treat "location" as already known from selectedAreas, so do NOT ask "Where is the pain?".

If this is the FIRST turn, prefer asking about the QUALITY of symptoms as a single-choice question with natural options.

Order your questions to ask ONLY what is still unknown, following this priority:
1) quality -> single-choice with friendly options
2) severity (1-10) -> number/scale (unit "1-10")
3) duration/onset -> short text prompt // NOTE: to have a duration in hours/days, user prompt validation
4) associated symptoms -> MULTI-SELECT with domain-specific options
5) triggers -> MULTI-SELECT

Stop early if you determine the likely diagnosis has high confidence (expected confidence ≥0.7)
or if there’s nothing more relevant to ask.

Context for reference (do not include in question):
- body areas: ${JSON.stringify(selectedAreas)}
- known answers: ${JSON.stringify(answers)}
- already covered topics: ${JSON.stringify(askedTopics)}
- questions remaining: ${questionsLeft}

Return STRICT JSON adhering to QUESTION_SCHEMA.

If no further relevant questions can be asked, return:
{"id":"_stop","text":"_stop","type":"text","topic":"stop"}
`.trim();
}

function buildDiagnosisPrompt(
  locale: string,
  selectedAreas: string[],
  answers: Record<string, any>
) {
  const tag = normalizeLocaleTag(locale);
  const allowed = allowedDxForAreas(selectedAreas);

  // and here I have for diagnosis
  return `
You are a clinical triage assistant. Produce the most likely differential diagnosis.
Write in "${tag}" (concise, friendly, non-alarming).

Inputs:
- body areas: ${JSON.stringify(selectedAreas)}
- answers: ${JSON.stringify(answers)}

${allowed ? `When assigning diagnoses, choose ONLY from this list unless none fits reasonably:
${JSON.stringify(allowed)}
If none fits, you may use "Other (specify)". Prefer specific labels over generic ones.` : ""}

Return STRICT JSON (DIAGNOSIS_SCHEMA).

Requirements:
- 1–5 hypotheses with ICD10 or SNOMED, each with probability 0..1; probabilities MUST approximately sum to 1.0.
- "explanation_patient": write 2–4 short, friendly sentences as if you are summarizing the case for the patient.
  Example style: "У вас уже 3 дня кашель, температура и колющая боль, усиливающаяся при вдохе — это похоже на инфекцию лёгких."
- "actions_now": 2–5 short, patient-friendly bullet-style suggestions (3–7 words each, e.g. "Пейте больше жидкости").
- "seek_care_if": 3–6 short, bullet-style red-flag conditions (3–7 words each, e.g. "Усиливается одышка").
- "summary_clinician": brief bullet summary for a clinician (HPI, ROS highlights, DDx, Plan).
`.trim();
}

// It is not the medical substitute, it is llm prompts

// vertex call with hard timeout // temperature in parameter
async function llmJson(schema: any, prompt: string, ms = 55_000, temperature = 0.3) {

  // here I declare timer, I need it to clear timeout later
  // because if I dont clear, timeout will fire even after success
  let timer: ReturnType<typeof setTimeout> | undefined;

  const timeout = new Promise<never>((_, reject) =>

    // Window: setTimeout() method (2026) MDN Web Docs.
    // Available at: https://developer.mozilla.org/en-US/docs/Web/API/Window/setTimeout (Accessed: March 12, 2026).
    // here I create timeout promise, if too long then reject
    timer = setTimeout(() => {
      logger.error("LLM TIMEOUT", {ms});

      // Promise (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise (Accessed: March 12, 2026).
      // reject is when promise is failed
      reject(new HttpsError("deadline-exceeded", "LLM timeout"));
    }, ms)
  );

  const task = (async () => {
    try {

      // here I call vertex model
      const resp = await generativeModel.generateContent({
        contents: [{role: "user", parts: [{text: prompt}]}],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: schema as any,
          temperature,
        },
      });

      // Optional chaining (?.) (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Optional_chaining (Accessed: March 12, 2026).
      // Nullish coalescing operator (??) (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Nullish_coalescing (Accessed: March 12, 2026).
      // here I get text from model response, if null then "{}"
      const text = resp.response?.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";

      logger.info("LLM raw preview", {preview: text.slice(0, 200)});

      try {
        // here I parse JSON from model
        return JSON.parse(text);
      } catch (e) {

        // if model return not JSON, I log error
        logger.error("LLM returned non-JSON", {textPreview: text.slice(0, 400)});

        throw new HttpsError("internal", "LLM returned non-JSON", {
          preview: text.slice(0, 400),
        });
      }

    } catch (e: any) {

      // here I log error from vertex or network
      logger.error("generateContent failed", {
        msg: e?.message,
        code: e?.code,
        name: e?.name,
        details: e?.details,
        stack: e?.stack?.split("\n").slice(0, 5).join("\n"),
      });

      // if already HttpsError, I dont override it
      if (e instanceof HttpsError) throw e;

      throw new HttpsError("internal", e?.message || "LLM call failed", {
        code: e?.code,
        details: e?.details,
      });
    }
  })();

  // Promise.Race() (2026) MDN Web Docs.
  // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/race (Accessed: March 12, 2026).
  // here I race between task and timeout
  try {
    return await Promise.race([task, timeout]);
  } finally {

    // VERY IMPORTANT: clear timeout always
    // because before I had bug: timeout fired after success
    if (timer) clearTimeout(timer);
  }
}

/* Final text composer */
function makePatientAndClinicianText(tag: string, diagRaw: any) {
  const diag = normalizeDx(diagRaw);

  // Array.isArray() (2026) MDN Web Docs. Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/isArray (Accessed: March 12, 2026).
  const dx = Array.isArray(diag.dx) ? diag.dx : [];

  // results in percentage, so it will show like ~45% this and ~32% that
  const allDxList = dx.map(
    (d: any) => `- ${d?.label ?? "—"} (~${d?.pct ?? toPct(d?.prob ?? 0)}%)`
  ).join("\n");

  const explanation = (diag.explanation_patient || "").trim();
  const actions = (Array.isArray(diag.actions_now) ? diag.actions_now : []).filter(Boolean);
  const seek = (Array.isArray(diag.seek_care_if) ? diag.seek_care_if : []).filter(Boolean);

  const dxPercents = dx.map((d: any) => ({
    label: d.label,
    code: d.code,
    system: d.system,
    pct: d?.pct ?? toPct(d?.prob ?? 0),
  }));

  if (tag === "ru-RU") {
    const patientText =
      `Вероятные диагнозы:\n${allDxList}\n\n` +
      (explanation ? `Что это значит: ${explanation}\n\n` : "") +
      (actions.length ? `Что делать сейчас:\n- ${actions.join("\n- ")}\n\n` : "") +
      (seek.length ? `Обратитесь очно сегодня/завтра ко врачу, если:\n- ${seek.join("\n- ")}` : "");

    const clinicianText = (diag.summary_clinician || "").trim();
    return {patientText, clinicianText, dxPercents, normalized: diag};
  } else {
    const patientText =
      `Likely diagnoses:\n${allDxList}\n\n` +
      (explanation ? `What it means: ${explanation}\n\n` : "") +
      (actions.length ? `What to do now:\n- ${actions.join("\n- ")}\n\n` : "") +
      (seek.length ? `Seek in-person care if:\n- ${seek.join("\n- ")}` : "");

    const clinicianText = (diag.summary_clinician || "").trim();
    return {patientText, clinicianText, dxPercents, normalized: diag};
  }
}

/* startSession */
export const startSession = onCall<{ locale: string; selectedAreas: string[] }>(
  {timeoutSeconds: 300, memory: "1GiB"},
  async (req) => {
    logger.info("startSession ENTER", {uid: req.auth?.uid, data: req.data});

    // here I check if user is authenticated
    // because callable function should work only for logged in user
    if (!req.auth) throw new HttpsError("unauthenticated", "Login required");

    const {locale, selectedAreas} = req.data || {};

    // here I validate input from client
    // locale must exist, and selectedAreas must be non empty array
    if (!locale || !Array.isArray(selectedAreas) || selectedAreas.length === 0) {
      throw new HttpsError("invalid-argument", "locale and selectedAreas are required");
    }

    // here I define the initial budget/limit for questions
    const initialBudget = 8;

    // here I normalize locale tag, for example ru-RU or en-US style
    const tag = normalizeLocaleTag(locale);

    // here I create firestore document for session
    const doc = await db.collection("sessions").add({
      userId: req.auth.uid,
      locale,
      selectedAreas,
      phase: "asking",
      answers: {},
      askedTopics: [],
      askedKeys: [],
      askedTexts: [],
      questionsLeft: initialBudget,

      // Update a Firestore document timestamp (2026) Google Cloud Documentation.
      // Available at: https://docs.cloud.google.com/firestore/docs/samples/firestore-data-set-server-timestamp (Accessed: March 12, 2026).
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    try {
      // here I call LLM for first question
      // I use temperature 0.5 for question, because it can be little flexible
      let q = await llmJson(
        QUESTION_SCHEMA,
        buildQuestionPrompt(locale, selectedAreas, {}, [], initialBudget),
        55_000,
        0.5
      );

      // here I sanitize question, so format and content are more stable
      q = sanitizeQuestion(q, tag, selectedAreas, []);

      // here I build canonical key from question text
      // it helps to avoid duplicates later
      const key = canonicalQuestionKey(q.text);

      // here I update firestore with first asked question data
      // doc is firestore document, and I save topic/text/key for duplicate control
      await doc.update({
        // JavaScript SDK (2026) Firebase.
        // Available at: https://firebase.google.com/docs/reference/js/v8/firebase.firestore.FieldValue (Accessed: March 12, 2026).
        askedTopics: FieldValue.arrayUnion(q.topic),
        askedTexts: FieldValue.arrayUnion(q.text),

        // I used here spread, if key exists then add askedKeys
        ...(key ? {askedKeys: FieldValue.arrayUnion(key)} : {}),

        updatedAt: FieldValue.serverTimestamp(),
      });

      // here I return first question with created session id
      return {type: "question", sessionId: doc.id, question: q};
    } catch (err: any) {
      logger.error("startSession ERROR", {
        msg: err?.message,
        code: err?.code,
        details: err?.details,
        stack: err?.stack?.split("\n").slice(0, 5).join("\n"),
      });

      // if error already firebase https error, I keep it as is
      if (err instanceof HttpsError) throw err;

      throw new HttpsError("internal", err?.message ?? "startSession error", {
        code: err?.code,
        details: err?.details,
      });
    } finally {
      // Promise.prototype.finally() (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/finally (Accessed: March 16, 2026).
      logger.info("startSession EXIT");
    }
  }
);

/* postAnswer */
export const postAnswer = onCall<{ sessionId: string; questionId: string; value: any }>(
  {timeoutSeconds: 300, memory: "1GiB"},
  async (req) => {
    logger.info("postAnswer ENTER", {uid: req.auth?.uid, data: req.data});

    // here I check auth, because only logged in user can answer session
    if (!req.auth) throw new HttpsError("unauthenticated", "Login required");

    const {sessionId, questionId, value} = (req.data || {}) as {
      sessionId?: string; questionId?: string; value?: any;
    };

    // here I validate input from client
    if (!sessionId || !questionId) {
      throw new HttpsError("invalid-argument", "sessionId and questionId are required");
    }

    try {
      // Firestore (2026) Firebase.
      // Available at: https://firebase.google.com/docs/firestore/pipelines/stages/input/collection (Accessed: March 16, 2026).
      const ref = db.collection("sessions").doc(sessionId);

      // I get the idea for the following code from here:
      // (2026) Stackoverflow.com.
      // Available at: https://stackoverflow.com/questions/46878913/cloud-firestore-how-to-fetch-a-document-reference-inside-my-collection-query-an (Accessed: March 16, 2026).

      // here I get document from firestore, like snapshot
      const snap = await ref.get();
      if (!snap.exists) throw new HttpsError("not-found", "Session not found");

      // and here I get data from firestore
      const s = snap.data() as any;

      // here I check that session belongs to this user
      // otherwise user maybe can send answer to other user session
      if (s.userId !== req.auth.uid) {
        throw new HttpsError("permission-denied", "This session does not belong to current user");
      }

      // here i get the language for user
      const tag = normalizeLocaleTag(s.locale);

      // if user skip question
      const isSkip = (typeof value === "string" && value === SKIP_VALUE);

      // here I copy answers from db to local object
      let answers = {...(s.answers || {})};

      // check how many questions left
      let left: number = typeof s.questionsLeft === "number" ? s.questionsLeft : 8;

      if (!isSkip) {
        // get only number from user values if possible
        const normalizedValue =
          (typeof value === "number" || typeof value === "string") ?
            normalizeNumericValue(value, true) :
            value;

        answers = {...answers, [questionId]: normalizedValue};
        left = Math.max(0, left - 1);

        // Add data to Cloud Firestore (2026) Firebase.
        // Available at: https://firebase.google.com/docs/firestore/manage-data/add-data (Accessed: March 16, 2026).
        await ref.update({
          [`answers.${questionId}`]: normalizedValue,
          questionsLeft: left,
          updatedAt: FieldValue.serverTimestamp(),
        });

        try {
          const valStr = typeof normalizedValue === "string" ?
            normalizedValue :
            String(normalizedValue ?? "");

          const coughWithBloodEN = "Cough with blood";
          const coughWithBloodRU = "Кашель с кровью";

          // Object.prototype.hasOwnProperty() (2026) MDN Web Docs.
          // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/hasOwnProperty (Accessed: March 16, 2026).
          const sputumAlready = Object.prototype.hasOwnProperty.call(answers, "sputum_color");
          const isCoughType = questionId === "cough_type";
          const isHemoptysis = valStr === coughWithBloodEN || valStr === coughWithBloodRU;

          if (isCoughType && isHemoptysis && !sputumAlready) {
            const sputumValue = tag === "ru-RU" ? "С кровью" : "Bloody";
            answers = {...answers, sputum_color: sputumValue};

            // the same logic I have done as before, now with sputum color
            await ref.update({
              ["answers.sputum_color"]: sputumValue,
              updatedAt: FieldValue.serverTimestamp(),
            });

            logger.info("Auto-set sputum_color due to cough with blood", {
              sessionId,
              sputumValue,
            });
          }
        } catch (e) {
          // I had problems with sputum color in questions, so I have this logging warn
          // Write and view logs (2026) Firebase.
          // Available at: https://firebase.google.com/docs/functions/writing-and-viewing-logs (Accessed: March 16, 2026).
          logger.warn("Failed to auto-set sputum_color from cough_type", {
            message: (e as any)?.message,
          });
        }
      } else {
        logger.warn("Client requested SKIP for duplicate question", {questionId});
      }

      const MIN_Q = 5; // need at least 5 answers before early stop
      const MAX_Q = 12; // 12 questions max
      const TOP1 = 0.7; // I need higher confidence for early stop, that is why is 0.7
      const MARGIN = 0.3;

      // Object.keys() (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/keys (Accessed: March 16, 2026).
      const answeredCount = Object.keys(answers).length;

      if (answeredCount >= MIN_Q) {
        try {
          // here I wait for Json from function, diagnosis schema, prompt, timeout and temperature
          const probeRaw = await llmJson(
            DIAGNOSIS_SCHEMA,
            buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
            55_000,
            0.2
          );

          const probe = normalizeDx(probeRaw);
          const ranked = Array.isArray(probe.dx) ? probe.dx : [];

          // we get probabilities of each diagnosis
          const p1 = ranked[0]?.prob ?? 0;
          const p2 = ranked[1]?.prob ?? 0;

          if (p1 >= TOP1 || (p1 - p2) >= MARGIN || answeredCount >= MAX_Q) {
            // and generate texts
            const {patientText, clinicianText, dxPercents, normalized} =
              makePatientAndClinicianText(tag, probe);

            const diag = {...normalized, patientText, clinicianText, dxPercents};

            await ref.update({
              phase: "result",
              provisionalDx: diag.dx,
              confidence: diag.confidence,
              updatedAt: FieldValue.serverTimestamp(),
            });

            return {type: "diagnosis", diagnosis: diag};
          }
        } catch {
          // here I ignore probe errors, because app still can ask next question
        }
      }

      // must ask for chest
      const must = nextMustAsk(tag, s.selectedAreas || [], answers, answeredCount);
      if (!isSkip && must) {
        await ref.update({
          askedTopics: FieldValue.arrayUnion(must.topic),
          askedTexts: FieldValue.arrayUnion(must.text),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {type: "question", question: must};
      }

      // letting LLM to ask further
      for (let attempt = 0; attempt < 3; attempt++) {
        let q = await llmJson(
          QUESTION_SCHEMA,
          buildQuestionPrompt(s.locale, s.selectedAreas, answers, s.askedTopics || [], left),
          55_000,
          0.5 // questions
        );

        // if patient never smoked, I skip and have fallback
        if (shouldSkipQuestion(q, answers, tag)) {
          const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
          if (fb) q = fb;
        }

        if (q.id === "_stop") {
          // if here minimum set of answers then I have more fallback questions
          if (answeredCount < MIN_Q) {
            const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
            if (fb) {
              q = fb;
            } else {
              // asking severity for end
              q = {
                id: "severity",
                topic: "severity",
                type: "scale",
                unit: "1-10",
                text: severityText(tag),
                options: [],
              } as any;
            }
          } else {
            const raw = await llmJson(
              DIAGNOSIS_SCHEMA,
              buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
              55_000,
              0.2
            );

            const {patientText, clinicianText, dxPercents, normalized} =
              makePatientAndClinicianText(tag, raw);

            const diag = {...normalized, patientText, clinicianText, dxPercents};

            await ref.update({
              phase: "result",
              provisionalDx: diag.dx,
              confidence: diag.confidence,
              updatedAt: FieldValue.serverTimestamp(),
            });

            return {type: "diagnosis", diagnosis: diag};
          }
        }

        q = sanitizeQuestion(q, tag, s.selectedAreas, s.askedTopics || []);

        // I need to ensure there are no duplicates
        const texts: string[] = Array.isArray(s.askedTexts) ? s.askedTexts : [];
        const key = canonicalQuestionKey(q.text);
        const idDup = Object.prototype.hasOwnProperty.call(answers, q.id);
        const topicDup = q.topic && (s.askedTopics || []).includes(q.topic);
        const keyDup = !!key && (s.askedKeys || []).includes(key);
        const semDup = isSemanticallyDuplicate(q.text, texts);
        const isDup = idDup || topicDup || keyDup || semDup;

        if (!isDup) {
          const update: Record<string, any> = {
            askedTopics: FieldValue.arrayUnion(q.topic),
            askedTexts: FieldValue.arrayUnion(q.text),
            updatedAt: FieldValue.serverTimestamp(),
          };

          if (key) update.askedKeys = FieldValue.arrayUnion(key);

          await ref.update(update);
          return {type: "question", question: q};
        }

        logger.warn("LLM duplicate question, regenerating", {
          attempt,
          qid: q.id,
          topic: q.topic,
          key,
          idDup,
          topicDup,
          keyDup,
          semDup,
        });
      }

      // if 3 failures then finish with fallback question or result
      if (answeredCount < MIN_Q) {
        const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
        const q = fb ?? {
          id: "duration",
          topic: "duration",
          type: "text",
          text: tag === "ru-RU" ? "Как давно это началось?" : "How long has this been going on?",
          options: [],
        } as any;

        const update: Record<string, any> = {
          askedTopics: FieldValue.arrayUnion(q.topic),
          askedTexts: FieldValue.arrayUnion(q.text),
          updatedAt: FieldValue.serverTimestamp(),
        };

        const key2 = canonicalQuestionKey(q.text);
        if (key2) update["askedKeys"] = FieldValue.arrayUnion(key2);

        await ref.update(update);
        return {type: "question", question: q};
      }

      const raw = await llmJson(
        DIAGNOSIS_SCHEMA,
        buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
        55_000,
        0.2
      );

      const {patientText, clinicianText, dxPercents, normalized} =
        makePatientAndClinicianText(tag, raw);

      const diag = {...normalized, patientText, clinicianText, dxPercents};

      await ref.update({
        phase: "result",
        provisionalDx: diag.dx,
        confidence: diag.confidence,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {type: "diagnosis", diagnosis: diag};
    } catch (err: any) {
      logger.error("postAnswer ERROR", {
        msg: err?.message,
        code: err?.code,
        details: err?.details,
        stack: err?.stack?.split("\n").slice(0, 5).join("\n"),
      });

      // if error already firebase https error, I keep it as is
      if (err instanceof HttpsError) throw err;

      throw new HttpsError("internal", err?.message ?? "postAnswer error", err?.details);
    } finally {
      logger.info("postAnswer EXIT");
    }
  }
);

/* testStartSession */
export const testStartSession = onRequest(
  {cors: true, timeoutSeconds: 120, memory: "1GiB"},
  async (req, res) => {
    logger.info("testStartSession ENTER", {
      method: req.method,
      query: req.query,
      body: req.body,
    });

    try {
      // here I allow both GET query and POST body
      const locale =
        (req.method === "GET" ? req.query.locale : req.body?.locale) as string || "ru-RU";

      const selectedAreas =
        req.method === "GET" ?
          (typeof req.query.areas === "string" ?
            (req.query.areas as string).split(",").map((x) => x.trim()).filter(Boolean) :
            ["chest"]) :
          (Array.isArray(req.body?.selectedAreas) && req.body.selectedAreas.length > 0 ?
            req.body.selectedAreas :
            ["chest"]);

      // here I define question budget for first session
      const initialBudget = 8;

      // here I normalize locale
      const tag = normalizeLocaleTag(locale);

      // here I create test firestore session
      // I use fake uid because this endpoint is only for testing
      const doc = await db.collection("sessions").add({
        userId: "test-user",
        locale,
        selectedAreas,
        phase: "asking",
        answers: {},
        askedTopics: [],
        askedKeys: [],
        askedTexts: [],
        questionsLeft: initialBudget,

        // Update a Firestore document timestamp (2026) Google Cloud Documentation.
        // Available at: https://docs.cloud.google.com/firestore/docs/samples/firestore-data-set-server-timestamp (Accessed: March 12, 2026).
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // for question I have temperature 0.5, they may be random
      let q = await llmJson(
        QUESTION_SCHEMA,
        buildQuestionPrompt(locale, selectedAreas, {}, [], initialBudget),
        55_000,
        0.5
      );

      // normalizing call
      q = sanitizeQuestion(q, tag, selectedAreas, []);
      const key = canonicalQuestionKey(q.text);

      // here I save first asked question to firestore
      await doc.update({
        // JavaScript SDK (2026) Firebase.
        // Available at: https://firebase.google.com/docs/reference/js/v8/firebase.firestore.FieldValue (Accessed: March 12, 2026).
        askedTopics: FieldValue.arrayUnion(q.topic),
        askedTexts: FieldValue.arrayUnion(q.text),
        ...(key ? {askedKeys: FieldValue.arrayUnion(key)} : {}),
        updatedAt: FieldValue.serverTimestamp(),
      });

      // here I return real sessionId, so it can be used in next Postman request
      res.json({type: "question", sessionId: doc.id, question: q});
    } catch (err: any) {
      logger.error("testStartSession ERROR", {
        msg: err?.message,
        code: err?.code,
        details: err?.details,
        stack: err?.stack?.split("\n").slice(0, 5).join("\n"),
      });

      res.status(500).json({error: err?.message || "Internal error"});
    } finally {
      logger.info("testStartSession EXIT");
    }
  }
);

/* testPostAnswer */
export const testPostAnswer = onRequest(
  {cors: true, timeoutSeconds: 120, memory: "1GiB"},
  async (req, res) => {
    logger.info("testPostAnswer ENTER", {
      method: req.method,
      query: req.query,
      body: req.body,
    });

    try {
      // here I allow both GET query and POST body
      const sessionId =
        (req.method === "GET" ? req.query.sessionId : req.body?.sessionId) as string;

      const questionId =
        (req.method === "GET" ? req.query.questionId : req.body?.questionId) as string;

      const value =
        req.method === "GET" ? req.query.value : req.body?.value;

      // here I validate required fields
      if (!sessionId || !questionId) {
        res.status(400).json({error: "sessionId and questionId are required"});
        return;
      }

      // Firestore (2026) Firebase.
      // Available at: https://firebase.google.com/docs/firestore/pipelines/stages/input/collection (Accessed: March 16, 2026).
      const ref = db.collection("sessions").doc(sessionId);

      // here I get document from firestore, like snapshot
      const snap = await ref.get();
      if (!snap.exists) {
        res.status(404).json({error: "Session not found"});
        return;
      }

      // and here I get data from firestore
      const s = snap.data() as any;

      // here i get the language for user
      const tag = normalizeLocaleTag(s.locale);

      // if user skip question
      const isSkip = (typeof value === "string" && value === SKIP_VALUE);

      // here I copy answers from db
      let answers = {...(s.answers || {})};

      // check how many questions left
      let left: number = typeof s.questionsLeft === "number" ? s.questionsLeft : 8;

      if (!isSkip) {
        // get only number from user values if possible
        const normalizedValue =
          (typeof value === "number" || typeof value === "string") ?
            normalizeNumericValue(value, true) :
            value;

        answers = {...answers, [questionId]: normalizedValue};
        left = Math.max(0, left - 1);

        // Add data to Cloud Firestore (2026) Firebase.
        // Available at: https://firebase.google.com/docs/firestore/manage-data/add-data (Accessed: March 16, 2026).
        await ref.update({
          [`answers.${questionId}`]: normalizedValue,
          questionsLeft: left,
          updatedAt: FieldValue.serverTimestamp(),
        });

        try {
          const valStr = typeof normalizedValue === "string" ?
            normalizedValue :
            String(normalizedValue ?? "");

          const coughWithBloodEN = "Cough with blood";
          const coughWithBloodRU = "Кашель с кровью";

          // Object.prototype.hasOwnProperty() (2026) MDN Web Docs.
          // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/hasOwnProperty (Accessed: March 16, 2026).
          const sputumAlready = Object.prototype.hasOwnProperty.call(answers, "sputum_color");
          const isCoughType = questionId === "cough_type";
          const isHemoptysis = valStr === coughWithBloodEN || valStr === coughWithBloodRU;

          if (isCoughType && isHemoptysis && !sputumAlready) {
            const sputumValue = tag === "ru-RU" ? "С кровью" : "Bloody";
            answers = {...answers, sputum_color: sputumValue};

            // the same logic I have done as before, now with sputum color
            await ref.update({
              ["answers.sputum_color"]: sputumValue,
              updatedAt: FieldValue.serverTimestamp(),
            });

            logger.info("Auto-set sputum_color due to cough with blood", {
              sessionId,
              sputumValue,
            });
          }
        } catch (e) {
          // I had problems with sputum color in questions, so I have this logging warn
          // Write and view logs (2026) Firebase.
          // Available at: https://firebase.google.com/docs/functions/writing-and-viewing-logs (Accessed: March 16, 2026).
          logger.warn("Failed to auto-set sputum_color from cough_type", {
            message: (e as any)?.message,
          });
        }
      } else {
        logger.warn("Client requested SKIP for duplicate question", {questionId});
      }

      const MIN_Q = 5; // need at least 5 answers before early stop
      const MAX_Q = 12; // 12 questions max
      const TOP1 = 0.7; // I need higher confidence for early stop, that is why is 0.7
      const MARGIN = 0.3;

      // Object.keys() (2026) MDN Web Docs.
      // Available at: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/keys (Accessed: March 16, 2026).
      const answeredCount = Object.keys(answers).length;

      if (answeredCount >= MIN_Q) {
        try {
          // here I wait for Json from function, diagnosis schema, prompt, timeout and temperature
          const probeRaw = await llmJson(
            DIAGNOSIS_SCHEMA,
            buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
            55_000,
            0.2
          );

          const probe = normalizeDx(probeRaw);
          const ranked = Array.isArray(probe.dx) ? probe.dx : [];

          // we get probabilities of each diagnosis
          const p1 = ranked[0]?.prob ?? 0;
          const p2 = ranked[1]?.prob ?? 0;

          if (p1 >= TOP1 || (p1 - p2) >= MARGIN || answeredCount >= MAX_Q) {
            const {patientText, clinicianText, dxPercents, normalized} =
              makePatientAndClinicianText(tag, probe);

            const diag = {...normalized, patientText, clinicianText, dxPercents};

            await ref.update({
              phase: "result",
              provisionalDx: diag.dx,
              confidence: diag.confidence,
              updatedAt: FieldValue.serverTimestamp(),
            });

            res.json({type: "diagnosis", diagnosis: diag});
            return;
          }
        } catch {
          // here I ignore probe errors, because app still can ask next question
        }
      }

      // must ask for chest
      const must = nextMustAsk(tag, s.selectedAreas || [], answers, answeredCount);
      if (!isSkip && must) {
        await ref.update({
          askedTopics: FieldValue.arrayUnion(must.topic),
          askedTexts: FieldValue.arrayUnion(must.text),
          updatedAt: FieldValue.serverTimestamp(),
        });

        res.json({type: "question", question: must});
        return;
      }

      // letting LLM to ask further
      for (let attempt = 0; attempt < 3; attempt++) {
        let q = await llmJson(
          QUESTION_SCHEMA,
          buildQuestionPrompt(s.locale, s.selectedAreas, answers, s.askedTopics || [], left),
          55_000,
          0.5 // questions
        );

        // if patient never smoked, I skip and have fallback
        if (shouldSkipQuestion(q, answers, tag)) {
          const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
          if (fb) q = fb;
        }

        if (q.id === "_stop") {
          // if here minimum set of answers then I have more fallback questions
          if (answeredCount < MIN_Q) {
            const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
            if (fb) {
              q = fb;
            } else {
              // asking severity for end
              q = {
                id: "severity",
                topic: "severity",
                type: "scale",
                unit: "1-10",
                text: severityText(tag),
                options: [],
              } as any;
            }
          } else {
            const raw = await llmJson(
              DIAGNOSIS_SCHEMA,
              buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
              55_000,
              0.2
            );

            const {patientText, clinicianText, dxPercents, normalized} =
              makePatientAndClinicianText(tag, raw);

            const diag = {...normalized, patientText, clinicianText, dxPercents};

            await ref.update({
              phase: "result",
              provisionalDx: diag.dx,
              confidence: diag.confidence,
              updatedAt: FieldValue.serverTimestamp(),
            });

            res.json({type: "diagnosis", diagnosis: diag});
            return;
          }
        }

        q = sanitizeQuestion(q, tag, s.selectedAreas, s.askedTopics || []);

        // I need to ensure there are no duplicates
        const texts: string[] = Array.isArray(s.askedTexts) ? s.askedTexts : [];
        const key = canonicalQuestionKey(q.text);
        const idDup = Object.prototype.hasOwnProperty.call(answers, q.id);
        const topicDup = q.topic && (s.askedTopics || []).includes(q.topic);
        const keyDup = !!key && (s.askedKeys || []).includes(key);
        const semDup = isSemanticallyDuplicate(q.text, texts);
        const isDup = idDup || topicDup || keyDup || semDup;

        if (!isDup) {
          const update: Record<string, any> = {
            askedTopics: FieldValue.arrayUnion(q.topic),
            askedTexts: FieldValue.arrayUnion(q.text),
            updatedAt: FieldValue.serverTimestamp(),
          };

          if (key) update.askedKeys = FieldValue.arrayUnion(key);

          await ref.update(update);
          res.json({type: "question", question: q});
          return;
        }

        logger.warn("LLM duplicate question, regenerating", {
          attempt,
          qid: q.id,
          topic: q.topic,
          key,
          idDup,
          topicDup,
          keyDup,
          semDup,
        });
      }

      // if 3 failures then finish with fallback question or result
      if (answeredCount < MIN_Q) {
        const fb = nextFallbackQuestion(tag, s.selectedAreas || [], answers, s.askedTopics || []);
        const q = fb ?? {
          id: "duration",
          topic: "duration",
          type: "text",
          text: tag === "ru-RU" ? "Как давно это началось?" : "How long has this been going on?",
          options: [],
        } as any;

        const update: Record<string, any> = {
          askedTopics: FieldValue.arrayUnion(q.topic),
          askedTexts: FieldValue.arrayUnion(q.text),
          updatedAt: FieldValue.serverTimestamp(),
        };

        const key2 = canonicalQuestionKey(q.text);
        if (key2) update["askedKeys"] = FieldValue.arrayUnion(key2);

        await ref.update(update);
        res.json({type: "question", question: q});
        return;
      }

      const raw = await llmJson(
        DIAGNOSIS_SCHEMA,
        buildDiagnosisPrompt(s.locale, s.selectedAreas, answers),
        55_000,
        0.2
      );

      const {patientText, clinicianText, dxPercents, normalized} =
        makePatientAndClinicianText(tag, raw);

      const diag = {...normalized, patientText, clinicianText, dxPercents};

      await ref.update({
        phase: "result",
        provisionalDx: diag.dx,
        confidence: diag.confidence,
        updatedAt: FieldValue.serverTimestamp(),
      });

      res.json({type: "diagnosis", diagnosis: diag});
    } catch (err: any) {
      logger.error("testPostAnswer ERROR", {
        msg: err?.message,
        code: err?.code,
        details: err?.details,
        stack: err?.stack?.split("\n").slice(0, 5).join("\n"),
      });

      res.status(500).json({error: err?.message || "Internal error"});
    } finally {
      logger.info("testPostAnswer EXIT");
    }
  }
);