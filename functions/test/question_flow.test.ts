// and here imports for question functions

import {
  chestPriorityOrder,
  nextMustAsk,
  sanitizeQuestion,
  shouldSkipQuestion,
  nextFallbackQuestion,
  hasInvalidExclusiveMultiSelection,
  buildExclusiveMultiValidationMessage,
} from "../src/index";

describe("chestPriorityOrder", () => {
  test("pain starts with quality", () => {
    const result = chestPriorityOrder("Pain");
    // priorities
    expect(result?.[0]).toBe("quality");
    expect(result?.[1]).toBe("severity");
  });

  test("pressure starts with exertion_relation", () => {
    const result = chestPriorityOrder("Pressure/heaviness");
    expect(result?.[0]).toBe("exertion_relation");
  });

  test("tingling starts with palpation_tenderness", () => {
    const result = chestPriorityOrder("Tingling/numbness");
    expect(result?.[0]).toBe("palpation_tenderness");
  });

  test("return null for unknown feeling", () => {
    expect(chestPriorityOrder("something else")).toBeNull();
  });
});

describe("nextMustAsk", () => {
  test("return null if area is not chest", () => {
    const q = nextMustAsk("en-US", ["head"], {}, 2);
    expect(q).toBeNull();
  });

  test("return null before first answer", () => {
    const q = nextMustAsk("en-US", ["chest"], {}, 0);
    expect(q).toBeNull();
  });

  test("return first chest priority question for pain", () => {
    const q = nextMustAsk("en-US", ["chest"], {feeling: "Pain"}, 1);
    expect(q?.id).toBe("exertion_relation");
  });

  test("skip already answered question", () => {
    const q = nextMustAsk(
      "en-US",
      ["chest"],
      {feeling: "Pain", quality: "Burning"},
      2
    );
    expect(q?.id).not.toBe("quality");
  });

  test("skip relief_rest when exertion_relation is No", () => {
    const q = nextMustAsk(
      "en-US",
      ["chest"],
      {
        feeling: "Pressure/heaviness",
        exertion_relation: "No",
      },
      2
    );

    expect(q?.id).not.toBe("relief_rest");
  });

  test("return russian text for ru local", () => {
    const q = nextMustAsk("ru-RU", ["chest"], {feeling: "Боль"}, 1);
    expect(q?.text).toBeDefined();
    expect(typeof q?.text).toBe("string");
  });
});

describe("sanitizeQuestion", () => {
  test("add missing topic from text", () => {
    const q = sanitizeQuestion(
      {id: "q1", text: "Как давно это началось?", type: "text"},
      "ru-RU",
      ["chest"],
      ["quality"]
    );

    expect(q.topic).toBe("duration");
  });

  test("first turn to quality if topic misc", () => {
    const q = sanitizeQuestion(
      {id: "x", text: "Tell me more", type: "text", topic: "misc"},
      "en-US",
      ["chest"],
      []
    );

    expect(q.topic).toBe("quality");
    expect(q.type).toBe("single");
    expect(Array.isArray(q.options)).toBe(true);
  });

  test("first turn to quality if topic location", () => {
    const q = sanitizeQuestion(
      {id: "x", text: "Where is the pain?", type: "text", topic: "location"},
      "en-US",
      ["chest"],
      []
    );

    expect(q.topic).toBe("quality");
  });

  test("severity to scale 1-10", () => {
    const q = sanitizeQuestion(
      {id: "severity", text: "How bad is it?", topic: "severity"},
      "en-US",
      ["chest"],
      ["quality"]
    );
    // scale
    expect(q.type).toBe("scale");
    expect(q.unit).toBe("1-10");
  });

  test("add associated options chest", () => {
    const q = sanitizeQuestion(
      {id: "associated", text: "Associated symptoms?", topic: "associated"},
      "en-US",
      ["chest"],
      ["quality", "severity"]
    );

    expect(q.type).toBe("multi");
    expect(Array.isArray(q.options)).toBe(true);
    expect(q.options.length).toBeGreaterThan(0);
  });

  test("add trigger options", () => {
    const q = sanitizeQuestion(
      {id: "triggers", text: "What worsens pain?", topic: "triggers"},
      "en-US",
      ["chest"],
      ["quality", "severity"]
    );

    expect(q.type).toBe("multi");
    expect(Array.isArray(q.options)).toBe(true);
    expect(q.options.length).toBeGreaterThan(0);
  });

  test("add fallback yes/no options single question with empty options", () => {
    const q = sanitizeQuestion(
      {
        id: "pleuritic",
        text: "Does it hurt when breathing?",
        topic: "pleuritic",
        type: "single",
        options: [],
      },
      "en-US",
      ["chest"],
      ["quality"]
    );

    expect(q.options).toEqual(["Yes", "No"]);
  });

  test("set id from topic if id is missing", () => {
    const q = sanitizeQuestion(
      {
        text: "How bad is it?",
        topic: "severity",
        type: "text",
      },
      "en-US",
      ["chest"],
      ["quality"]
    );

    expect(q.id).toBe("severity");
  });
});

describe("shouldSkipQuestion", () => {
  test("skip smoking_duration if never smoked", () => {
    const result = shouldSkipQuestion(
      {
        id: "smoking_duration",
        text: "How long have you been smoking?",
      },
      {
        smoking_history: "I have never smoked",
      },
      "en-US"
    );

    expect(result).toBe(true);
  });

  test("skip smoking_duration if never smoked in russian", () => {
    const result = shouldSkipQuestion(
      {
        id: "smoking_duration",
        text: "Стаж курения?",
      },
      {
        smoking_history: "Никогда не курил",
      },
      "ru-RU"
    );

    expect(result).toBe(true);
  });

  test("skip sputum_color if already known", () => {
    const result = shouldSkipQuestion(
      {
        id: "sputum_color",
        text: "What color is your sputum?",
      },
      {
        sputum_color: "Bloody",
      },
      "en-US"
    );

    expect(result).toBe(true);
  });

  test("does not skip unrelated question", () => {
    const result = shouldSkipQuestion(
      {
        id: "fever_pattern",
        text: "Do you have fever?",
      },
      {},
      "en-US"
    );

    expect(result).toBe(false);
  });
});

describe("nextFallbackQuestion", () => {
  test("ask feeling first if missing", () => {
    const q = nextFallbackQuestion("en-US", ["chest"], {}, []);
    expect(q?.id).toBe("feeling");
  });

  test("ask quality if feeling says pain", () => {
    const q = nextFallbackQuestion(
      "en-US",
      ["chest"],
      {feeling: "Pain"},
      ["feeling"]
    );

    expect(q?.id).toBe("quality");
  });

  test("ask severity after quality", () => {
    const q = nextFallbackQuestion(
      "en-US",
      ["chest"],
      {feeling: "Pain", quality: "Burning"},
      ["feeling", "quality"]
    );

    expect(q?.id).toBe("severity");
  });

  test("ask duration if severity already covered", () => {
    const q = nextFallbackQuestion(
      "en-US",
      ["chest"],
      {
        feeling: "Pain",
        quality: "Burning",
        severity: 7,
      },
      ["feeling", "quality", "severity"]
    );

    expect(q?.id).toBe("duration");
  });
});

describe("exclusive multi selection validation", () => {
  test("reject None with another option", () => {
    expect(
      hasInvalidExclusiveMultiSelection(
        "chronic_conditions",
        ["None", "Asthma"],
        "en-US"
      )
    ).toBe(true);
  });

  test("reject Нет with another option", () => {
    expect(
      hasInvalidExclusiveMultiSelection(
        "chronic_conditions",
        ["Нет", "Астма"],
        "ru-RU"
      )
    ).toBe(true);
  });

  test("allow only None", () => {
    expect(
      hasInvalidExclusiveMultiSelection(
        "chronic_conditions",
        ["None"],
        "en-US"
      )
    ).toBe(false);
  });

  test("return false not array value", () => {
    expect(
      hasInvalidExclusiveMultiSelection(
        "chronic_conditions",
        "None",
        "en-US"
      )
    ).toBe(false);
  });

  test("build english validation message", () => {
    expect(
      buildExclusiveMultiValidationMessage("chronic_conditions", "en-US")
    ).toContain('You cannot select "None"');
  });

  test("build russian validation message", () => {
    expect(
      buildExclusiveMultiValidationMessage("chronic_conditions", "ru-RU")
    ).toContain('Нельзя выбирать "Нет"');
  });
});