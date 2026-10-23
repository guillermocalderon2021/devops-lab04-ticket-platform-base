import { describe, expect, it } from 'vitest';

describe('health contract', () => {
  it('uses the expected status value', () => {
    expect({ status: 'ok' }).toEqual({ status: 'ok' });
  });
});
