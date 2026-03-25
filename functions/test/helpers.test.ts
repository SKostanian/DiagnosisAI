// importing functions
import {
  normalizeText,
  canonicalQuestionKey,
  jaccardSimilarity,
  isSemanticallyDuplicate,
  normalizeLocaleTag,
  normalizeNumericValue,
  normalizeAnswerValue,
  toPct,
} from "../src/index";

// Globals (no date b) Jestjs.io. Available at: https://jestjs.io/docs/api (Accessed: March 25, 2026).

describe("normalizeText", () => {
  test("lowercases and removes punctuation", () => {
    expect(normalizeText("Hello, WORLD!!!")).toBe("hello world");
  });

  test("removes multiple spaces", () => {
    expect(normalizeText("  chest   pain   ")).toBe("chest pain");
  });

  test("supports russian text", () => {
    expect(normalizeText("Боль, в груди!!!")).toBe("боль в груди");
  });
});

describe("canonicalQuestionKey", () => {
  test("detects quality in English", () => {
    expect(canonicalQuestionKey("Pain quality")).toBe("quality");
  });

  test("detects severity in English", () => {
    expect(canonicalQuestionKey("Rate it on a scale of 1 to 10")).toBe("severity");
  });

  test("detects duration in Russian", () => {
    expect(canonicalQuestionKey("Как давно это началось?")).toBe("duration");
  });

  test("detects associated symptoms in Russian", () => {
    expect(canonicalQuestionKey("Есть ли тошнота или рвота?")).toBe("associated");
  });

  test("returns null for unknown question", () => {
    expect(canonicalQuestionKey("Tell me more")).toBeNull();
  });
});

describe("jaccardSimilarity", () => {
  test("returns 1 for identical texts", () => {
    expect(jaccardSimilarity("Chest pain and cough", "Chest pain and cough")).toBe(1);
  });

  test("returns low value for different texts", () => {
    expect(jaccardSimilarity("Chest pain", "Leg fracture")).toBeLessThan(0.5);
  });
});

describe("isSemanticallyDuplicate", () => {
  test("returns true for similar text", () => {
    expect(
      isSemanticallyDuplicate(
        "How long have you had the cough?",
        ["How long has the cough been going on?"],
        0.2
      )
    ).toBe(true);
  });

  test("returns false if unrelated text", () => {
    expect(
      isSemanticallyDuplicate(
        "Do you have fever?",
        ["What is your smoking status?"]
      )
    ).toBe(false);
  });
});

describe("normalizeLocaleTag", () => {
  test("maps ru to ru-RU", () => {
    expect(normalizeLocaleTag("ru")).toBe("ru-RU");
  });

  test("maps el to el-GR", () => {
    expect(normalizeLocaleTag("el")).toBe("el-GR");
  });

  test("defaults to en-US", () => {
    expect(normalizeLocaleTag("fr")).toBe("en-US");
  });
});

describe("normalizeNumericValue", () => {
  test("rounds numeric input", () => {
    expect(normalizeNumericValue(7.6)).toBe(8);
  });

  test("clamps below 0", () => {
    expect(normalizeNumericValue(-5)).toBe(0);
  });

  test("clamps above 10", () => {
    expect(normalizeNumericValue(22)).toBe(10);
  });

  test("parses string with comma", () => {
    expect(normalizeNumericValue("8,4")).toBe(8);
  });

  test("extracts number from text", () => {
    expect(normalizeNumericValue("pain is 9/10")).toBe(9);
  });

  test("returns trimmed string if no number", () => {
    expect(normalizeNumericValue("  severe  ")).toBe("severe");
  });
});

describe("normalizeAnswerValue", () => {
  test("normalizes severity as number", () => {
    expect(normalizeAnswerValue("severity", "8", "en-US")).toBe(8);
  });

  test("trims plain string", () => {
    expect(normalizeAnswerValue("quality", "  Burning  ", "en-US")).toBe("Burning");
  });

  test("trims arrays of strings", () => {
    expect(
      normalizeAnswerValue("associated", [" Fever ", " Cough "], "en-US")
      // and it needs to be equal
    ).toEqual(["Fever", "Cough"]);
  });
});

describe("toPct", () => {
  test("converts probability to percent", () => {
    expect(toPct(0.73)).toBe(73);
  });

  test("clamps invalid high values", () => {
    expect(toPct(2)).toBe(100);
  });

  test("handles invalid input", () => {
    expect(toPct(Number.NaN)).toBe(0);
  });
});