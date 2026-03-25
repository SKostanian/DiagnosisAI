// it is mock for normalizeDx function

import {normalizeDx} from "../src/index";

describe("normalizeDx", () => {
  test("clamp probabilities into 0..1", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 2},
        {label: "B", code: "B1", system: "ICD10", prob: -1},
      ],
      confidence: 0.5,
    });

    // Expect (2026) Jestjs.io. Available at: https://jestjs.io/docs/expect (Accessed: March 25, 2026).
    expect(result.dx[0].prob).toBeGreaterThanOrEqual(0);
    expect(result.dx[0].prob).toBeLessThanOrEqual(1);
    expect(result.dx[1].prob).toBeGreaterThanOrEqual(0);
    expect(result.dx[1].prob).toBeLessThanOrEqual(1);
  });

  test("normalize probabilities to sum to 1", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 0.8},
        {label: "B", code: "B1", system: "ICD10", prob: 0.8},
      ],
    });

    const sum = result.dx.reduce((s: number, d: any) => s + d.prob, 0);
    expect(sum).toBeCloseTo(1, 5);
  });

  test("distribute 50 on 50 when probs zero", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 0},
        {label: "B", code: "B1", system: "ICD10", prob: 0},
      ],
    });

    expect(result.dx[0].prob).toBeCloseTo(0.5, 5);
    expect(result.dx[1].prob).toBeCloseTo(0.5, 5);
  });

  test("add pct field", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 0.75},
        {label: "B", code: "B1", system: "ICD10", prob: 0.25},
      ],
    });

    expect(result.dx[0].pct).toBeDefined();
    expect(result.dx[1].pct).toBeDefined();
  });

  test("sort by prob on descending", () => {
    const result = normalizeDx({
      dx: [
        {label: "Low", code: "L1", system: "ICD10", prob: 0.2},
        {label: "High", code: "H1", system: "ICD10", prob: 0.8},
      ],
    });

    expect(result.dx[0].label).toBe("High");
    expect(result.dx[1].label).toBe("Low");
  });

  test("use confidence if it is finite", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 0.6},
        {label: "B", code: "B1", system: "ICD10", prob: 0.4},
      ],
      confidence: 0.42,
    });

    expect(result.confidence).toBe(0.42);
  });

  test("use top probability as fallback confidence", () => {
    const result = normalizeDx({
      dx: [
        {label: "A", code: "A1", system: "ICD10", prob: 0.9},
        {label: "B", code: "B1", system: "ICD10", prob: 0.1},
      ],
    });

    expect(result.confidence).toBeCloseTo(0.9, 5);
  });

  test("build fallback diagnoses for chest when dx empty", () => {
    const result = normalizeDx({dx: []}, ["chest"]);

    expect(Array.isArray(result.dx)).toBe(true);
    expect(result.dx.length).toBeGreaterThan(0);
  });

  test("chest fallback diagnoses are normalized to sum to 1", () => {
    const result = normalizeDx({dx: []}, ["chest"]);

    const sum = result.dx.reduce((s: number, d: any) => s + d.prob, 0);
    expect(sum).toBeCloseTo(1, 5);
  });

  test("return empty dx array for unknown area, no diagnoses", () => {
    const result = normalizeDx({}, ["unknown"]);

    expect(Array.isArray(result.dx)).toBe(true);
    expect(result.dx.length).toBe(0);
    expect(result.confidence).toBe(0);
  });
});