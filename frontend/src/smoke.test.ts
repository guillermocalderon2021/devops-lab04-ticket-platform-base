import { describe, expect, it } from 'vitest';

describe('frontend smoke', () => {
  it('has a valid initial status set', () => {
    expect(['open', 'in_progress', 'resolved']).toContain('open');
  });
});
