import assert from 'node:assert/strict';
import test from 'node:test';
import { validContext, validMessages, urgentSafetyResponse, safeSummary } from './policy.ts';

test('accepts minimal structured context', () => assert.equal(validContext({ metrics: [{ name: 'HRV', value: 42, unit: 'ms' }] }), true));
test('rejects raw HealthKit samples and extra keys', () => assert.equal(validContext({ samples: [{ value: 42 }] }), false));
test('rejects oversized journal notes', () => assert.equal(validContext({ journal: [{ notes: 'a'.repeat(1001) }] }), false));
test('rejects invalid numeric readings', () => assert.equal(validContext({ metrics: [{ value: Number.POSITIVE_INFINITY }] }), false));
test('accepts one user question', () => assert.equal(validMessages([{ role: 'user', content: '¿Cómo dormí?' }]), true));
test('requires final user message', () => assert.equal(validMessages([{ role: 'assistant', content: 'Hola' }]), false));
test('limits message length', () => assert.equal(validMessages([{ role: 'user', content: 'a'.repeat(4001) }]), false));
test('flags severe symptoms without diagnosing', () => {
  const answer = urgentSafetyResponse('Tengo dolor en el pecho y dificultad para respirar');
  assert.match(answer, /atención urgente/);
  assert.match(answer, /No puedo evaluarlo ni diagnosticarlo/);
});
test('does not flag ordinary training question', () => assert.equal(urgentSafetyResponse('¿Cómo entrenar mañana?'), null));
test('memory summary is bounded', () => assert.equal(safeSummary('x'.repeat(2000)).length, 1500));
