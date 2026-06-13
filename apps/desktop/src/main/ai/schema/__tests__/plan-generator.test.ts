/**
 * Tests for generateImplementationPlanFromSpec — the non-structured plan
 * generation fallback used when a provider doesn't reliably support
 * Output.object() (e.g. z.ai / GLM).
 */
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { writeFileSync, readFileSync, mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';

// generateImplementationPlanFromSpec lazy-imports generateText from 'ai'.
// Mock it so no real LLM call is made.
const generateTextMock = vi.fn();
vi.mock('ai', () => ({
  generateText: (...args: unknown[]) => generateTextMock(...args),
}));

import { generateImplementationPlanFromSpec } from '../structured-output';

describe('generateImplementationPlanFromSpec', () => {
  let testDir: string;

  beforeEach(() => {
    testDir = mkdtempSync(join(tmpdir(), 'plan-gen-'));
    generateTextMock.mockReset();
  });

  afterEach(() => {
    rmSync(testDir, { recursive: true, force: true });
  });

  it('generates and writes a valid plan from spec.md', async () => {
    writeFileSync(join(testDir, 'spec.md'), '# Feature\nDo a thing.');

    generateTextMock.mockResolvedValue({
      text: JSON.stringify({
        feature: 'Feature',
        workflow_type: 'feature',
        phases: [
          {
            id: '1',
            name: 'Setup',
            subtasks: [
              { id: '1-1', title: 'Init', description: 'Init project', status: 'pending' },
            ],
          },
        ],
      }),
    });

    const result = await generateImplementationPlanFromSpec(testDir, {} as never);

    expect(result.valid).toBe(true);
    const written = JSON.parse(readFileSync(join(testDir, 'implementation_plan.json'), 'utf-8'));
    expect(written.phases).toHaveLength(1);
    expect(written.phases[0].subtasks[0].title).toBe('Init');

    // The spec content was passed to the model
    expect(generateTextMock).toHaveBeenCalledTimes(1);
    expect((generateTextMock.mock.calls[0][0] as { prompt: string }).prompt).toContain('Do a thing.');
  });

  it('coerces a flat "steps" response into phases via the schema', async () => {
    writeFileSync(join(testDir, 'spec.md'), '# Feature\nBuild it.');
    // Model emits flat steps instead of phases[] — schema coercion wraps them.
    generateTextMock.mockResolvedValue({
      text: JSON.stringify({
        feature: 'Feature',
        steps: [
          { id: 's1', title: 'Step one', description: 'do one', status: 'pending' },
          { id: 's2', title: 'Step two', description: 'do two', status: 'pending' },
        ],
      }),
    });

    const result = await generateImplementationPlanFromSpec(testDir, {} as never);
    expect(result.valid).toBe(true);
    const written = JSON.parse(readFileSync(join(testDir, 'implementation_plan.json'), 'utf-8'));
    expect(written.phases).toHaveLength(1);
    expect(written.phases[0].subtasks).toHaveLength(2);
  });

  it('accepts a markdown-fenced JSON response', async () => {
    writeFileSync(join(testDir, 'spec.md'), '# Feature\nBuild it.');
    generateTextMock.mockResolvedValue({
      text: '```json\n' + JSON.stringify({
        phases: [{ id: '1', name: 'P1', subtasks: [{ id: '1-1', title: 'T', description: 'd', status: 'pending' }] }],
      }) + '\n```',
    });

    const result = await generateImplementationPlanFromSpec(testDir, {} as never);
    expect(result.valid).toBe(true);
  });

  it('returns invalid when no spec source exists', async () => {
    const result = await generateImplementationPlanFromSpec(testDir, {} as never);
    expect(result.valid).toBe(false);
    expect(result.errors[0]).toContain('No spec.md');
    expect(generateTextMock).not.toHaveBeenCalled();
  });

  it('returns invalid when the response is not schema-valid JSON', async () => {
    writeFileSync(join(testDir, 'spec.md'), '# Feature\nBuild it.');
    generateTextMock.mockResolvedValue({ text: 'Sorry, I cannot help with that.' });

    const result = await generateImplementationPlanFromSpec(testDir, {} as never);
    expect(result.valid).toBe(false);
  });

  it('returns invalid (not throw) when generateText rejects', async () => {
    writeFileSync(join(testDir, 'spec.md'), '# Feature\nBuild it.');
    generateTextMock.mockRejectedValue(new Error('network down'));

    const result = await generateImplementationPlanFromSpec(testDir, {} as never);
    expect(result.valid).toBe(false);
    expect(result.errors[0]).toContain('network down');
  });
});
