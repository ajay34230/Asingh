/**
 * DOM overlay: turn banner, roll readout, toast messages, menu and the result
 * panel. Offline mode shows no online player panels; the only per-seat
 * information is the colour of whose turn it is.
 */
import { MODES } from './game-controller.js';
import { QUALITY_PRESETS } from '../render/scene.js';

const COLOR_NAMES = { red: 'Red', green: 'Green', yellow: 'Yellow', blue: 'Blue' };

export function createHud(doc, { onNewGame, onModeChange, onQualityChange }) {
  const $ = (id) => doc.getElementById(id);
  const turnChip = $('turn-chip');
  const turnText = $('turn-text');
  const rollText = $('roll-text');
  const hint = $('hint');
  const toasts = $('toasts');
  const result = $('result');
  const resultList = $('result-list');
  const menu = $('menu');
  const menuButton = $('menu-button');
  const modeSelect = $('mode-select');
  const qualitySelect = $('quality-select');

  for (const [key, mode] of Object.entries(MODES)) {
    const opt = doc.createElement('option');
    opt.value = key;
    opt.textContent = mode.label;
    modeSelect.appendChild(opt);
  }
  for (const [key, preset] of Object.entries(QUALITY_PRESETS)) {
    const opt = doc.createElement('option');
    opt.value = key;
    opt.textContent = preset.label;
    qualitySelect.appendChild(opt);
  }

  modeSelect.addEventListener('change', () => onModeChange(modeSelect.value));
  qualitySelect.addEventListener('change', () => onQualityChange(qualitySelect.value));
  $('new-game').addEventListener('click', () => {
    setMenuOpen(false);
    onNewGame();
  });
  $('play-again').addEventListener('click', () => {
    hideResult();
    onNewGame();
  });
  menuButton.addEventListener('click', () => setMenuOpen(menu.hidden));

  function setMenuOpen(open) {
    menu.hidden = !open;
    menuButton.setAttribute('aria-expanded', String(open));
  }

  function setTurn(color, human, mode) {
    if (!color) {
      turnChip.className = 'chip';
      turnText.textContent = 'Game over';
      return;
    }
    turnChip.className = `chip ${color}`;
    if (human) {
      const multi = MODES[mode]?.seats.filter((s) => s.human).length > 1;
      turnText.textContent = multi ? `${COLOR_NAMES[color]}'s turn` : 'Your turn';
    } else {
      turnText.textContent = `${COLOR_NAMES[color]} is thinking…`;
    }
  }

  function setRoll(text) {
    rollText.textContent = text;
  }

  function setRollEnabled(enabled) {
    hint.textContent = enabled ? 'Tap the dice to roll' : '';
    doc.body.classList.toggle('can-roll', enabled);
  }

  /** Short toast message; `tone` is 'info' | 'good' | 'warn' | 'error'. */
  function announce(text, tone = 'info') {
    const el = doc.createElement('div');
    el.className = `toast ${tone}`;
    el.textContent = text;
    toasts.appendChild(el);
    while (toasts.children.length > 3) toasts.firstElementChild.remove();
    setTimeout(() => {
      el.classList.add('out');
      setTimeout(() => el.remove(), 300);
    }, 2200);
  }

  function showResult(ranking, mode) {
    resultList.textContent = '';
    for (const entry of ranking) {
      const li = doc.createElement('li');
      const chip = doc.createElement('span');
      chip.className = `chip ${entry.color}`;
      const label = doc.createElement('span');
      const who = entry.human && MODES[mode].seats.filter((s) => s.human).length === 1 ? 'You' : COLOR_NAMES[entry.color];
      label.textContent = `${entry.place}. ${who}`;
      li.append(chip, label);
      resultList.appendChild(li);
    }
    result.hidden = false;
  }

  function hideResult() {
    result.hidden = true;
  }

  function syncControls({ mode, quality }) {
    modeSelect.value = mode;
    qualitySelect.value = quality;
  }

  return {
    setTurn, setRoll, setRollEnabled, announce, showResult, hideResult, setMenuOpen, syncControls,
  };
}
