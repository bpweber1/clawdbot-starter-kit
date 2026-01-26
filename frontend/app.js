// ============================================================================
// Clawdbot Starter Kit — Frontend Wizard
// ============================================================================

const TOTAL_STEPS = 5;
let currentStep = 1;
let authMode = 'api'; // 'api' or 'max'

const VIBE_MAP = {
  professional: {
    vibe: "Professional, precise, and thorough. Clear communication with attention to detail. Formal but approachable.",
    short: "Professional & precise"
  },
  casual: {
    vibe: "Casual, warm, and friendly. Like talking to a smart friend who gets things done. Relaxed but reliable.",
    short: "Casual & friendly"
  },
  technical: {
    vibe: "Technical, direct, no fluff. Get to the point. Code speaks louder than words. Efficient and sharp.",
    short: "Technical & direct"
  },
  creative: {
    vibe: "Creative, energetic, always bringing fresh ideas. Enthusiastic but focused. Makes work feel exciting.",
    short: "Creative & energetic"
  }
};

// ============================================================================
// Step Navigation
// ============================================================================

function updateProgress() {
  const fill = document.getElementById('progressFill');
  fill.style.width = `${(currentStep / TOTAL_STEPS) * 100}%`;

  document.querySelectorAll('.step').forEach(step => {
    const num = parseInt(step.dataset.step);
    step.classList.remove('active', 'completed');
    if (num === currentStep) step.classList.add('active');
    else if (num < currentStep) step.classList.add('completed');
  });
}

function showStep(n) {
  document.querySelectorAll('.wizard-step').forEach(s => s.classList.remove('active'));
  document.getElementById(`step${n}`).classList.add('active');
  currentStep = n;
  updateProgress();
  window.scrollTo({ top: 0, behavior: 'smooth' });
  // Re-init Lucide icons for newly visible elements
  if (window.lucide) lucide.createIcons();
}

function nextStep() {
  if (currentStep === 1) {
    const name = document.getElementById('userName').value.trim();
    if (!name) {
      document.getElementById('userName').focus();
      document.getElementById('userName').style.borderColor = '#EF4444';
      setTimeout(() => document.getElementById('userName').style.borderColor = '', 2000);
      return;
    }
  }
  if (currentStep === 2) {
    const name = document.getElementById('agentName').value.trim();
    if (!name) {
      document.getElementById('agentName').focus();
      document.getElementById('agentName').style.borderColor = '#EF4444';
      setTimeout(() => document.getElementById('agentName').style.borderColor = '', 2000);
      return;
    }
  }
  if (currentStep < TOTAL_STEPS) showStep(currentStep + 1);
}

function prevStep() {
  if (currentStep > 1) showStep(currentStep - 1);
}

// ============================================================================
// Skill Pack Selection
// ============================================================================

function toggleAll(checkbox) {
  document.querySelectorAll('input[name="packs"]').forEach(cb => {
    cb.checked = checkbox.checked;
  });
}

// ============================================================================
// Auth Mode Toggle
// ============================================================================

function switchAuth(mode) {
  authMode = mode;
  
  // Toggle tab active states
  document.querySelectorAll('.auth-tab').forEach(tab => {
    tab.classList.toggle('active', tab.dataset.auth === mode);
  });
  
  // Toggle panel visibility
  document.getElementById('authApi').classList.toggle('active', mode === 'api');
  document.getElementById('authMax').classList.toggle('active', mode === 'max');
}

// ============================================================================
// Additional API Keys Toggle
// ============================================================================

function toggleAdditionalKeys() {
  const panel = document.getElementById('additionalKeysPanel');
  const btn = panel.previousElementSibling || document.querySelector('.expand-btn');
  
  if (panel.style.display === 'none') {
    panel.style.display = 'flex';
    // Re-init Lucide for any new icons
    if (window.lucide) lucide.createIcons();
  } else {
    panel.style.display = 'none';
  }
}

// ============================================================================
// Config Generation
// ============================================================================

function buildConfig() {
  const vibeChoice = document.querySelector('input[name="agentVibe"]:checked')?.value || 'professional';
  const customVibe = document.getElementById('agentVibeCustom').value.trim();
  const vibeData = customVibe
    ? { vibe: customVibe, short: 'Custom' }
    : VIBE_MAP[vibeChoice];

  const packs = Array.from(document.querySelectorAll('input[name="packs"]:checked'))
    .map(cb => cb.value)
    .join(',') || 'C';

  const config = {
    user: {
      name: document.getElementById('userName').value.trim() || 'User',
      timezone: document.getElementById('userTimezone').value,
      role: document.getElementById('userRole').value.trim() || '',
      focus: document.getElementById('userFocus').value.trim() || '',
      style: document.getElementById('userStyle').value.trim() || ''
    },
    agent: {
      name: document.getElementById('agentName').value.trim() || 'Assistant',
      emoji: document.getElementById('agentEmoji').value.trim() || '🤖',
      vibe: vibeData.vibe,
      vibeShort: vibeData.short
    },
    skills: packs,
    integrations: {
      telegram: document.getElementById('telegramToken').value.trim()
    },
    workspace: '~/clawd'
  };

  // Auth — API key or Claude Max token
  if (authMode === 'api') {
    config.integrations.anthropic = document.getElementById('anthropicKey').value.trim();
  } else {
    config.integrations.claudeMax = document.getElementById('claudeMaxToken').value.trim();
  }

  // Additional API keys
  const openai = document.getElementById('openaiKey')?.value.trim();
  const elevenlabs = document.getElementById('elevenlabsKey')?.value.trim();
  const brave = document.getElementById('braveKey')?.value.trim();
  
  if (openai) config.integrations.openai = openai;
  if (elevenlabs) config.integrations.elevenlabs = elevenlabs;
  if (brave) config.integrations.brave = brave;

  return config;
}

function generateDeploy() {
  const config = buildConfig();
  const configB64 = btoa(unescape(encodeURIComponent(JSON.stringify(config))));

  const command = `curl -fsSL https://raw.githubusercontent.com/theaiintegrationhub/clawdbot-starter-kit/main/installer/setup.sh -o /tmp/setup.sh && \\
  bash /tmp/setup.sh --config ${configB64}`;

  showStep(5);

  document.getElementById('deployCommand').textContent = command;

  // Preview grid
  const grid = document.getElementById('previewGrid');
  const packLabels = {
    'M': 'Marketing', 'D': 'Developer', 'O': 'Operations', 'W': 'Media', 'C': 'Core'
  };
  const selectedPacks = config.skills.split(',').map(p => packLabels[p] || p).join(', ');

  const authLabel = authMode === 'api' ? 'API Key' : 'Claude Max';
  const authConfigured = authMode === 'api' 
    ? config.integrations.anthropic 
    : config.integrations.claudeMax;

  const additionalKeys = ['openai', 'elevenlabs', 'brave']
    .filter(k => config.integrations[k])
    .map(k => k.charAt(0).toUpperCase() + k.slice(1))
    .join(', ');

  grid.innerHTML = `
    <div class="preview-label">Owner</div><div class="preview-value">${config.user.name}</div>
    <div class="preview-label">Timezone</div><div class="preview-value">${config.user.timezone}</div>
    <div class="preview-label">Agent Name</div><div class="preview-value">${config.agent.name} ${config.agent.emoji}</div>
    <div class="preview-label">Personality</div><div class="preview-value">${config.agent.vibeShort}</div>
    <div class="preview-label">Skill Packs</div><div class="preview-value">Core + ${selectedPacks}</div>
    <div class="preview-label">Auth Mode</div><div class="preview-value">${authConfigured ? '✓ ' : '— '}${authLabel}</div>
    ${additionalKeys ? `<div class="preview-label">Additional Keys</div><div class="preview-value">✓ ${additionalKeys}</div>` : ''}
    <div class="preview-label">Telegram</div><div class="preview-value">${config.integrations.telegram ? '✓ Configured' : '— Skipped'}</div>
  `;
}

// ============================================================================
// Copy & Download
// ============================================================================

function copyCommand() {
  const text = document.getElementById('deployCommand').textContent;
  navigator.clipboard.writeText(text).then(() => {
    const btn = document.getElementById('copyBtn');
    btn.innerHTML = '<i data-lucide="clipboard-check"></i> Copied!';
    btn.classList.add('copied');
    if (window.lucide) lucide.createIcons();
    setTimeout(() => {
      btn.innerHTML = '<i data-lucide="clipboard"></i> Copy';
      btn.classList.remove('copied');
      if (window.lucide) lucide.createIcons();
    }, 2000);
  });
}

function downloadConfig() {
  const config = buildConfig();
  const blob = new Blob([JSON.stringify(config, null, 2)], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'clawdbot-config.json';
  a.click();
  URL.revokeObjectURL(url);
}

// ============================================================================
// Init
// ============================================================================

document.addEventListener('DOMContentLoaded', () => {
  updateProgress();

  // Initialize Lucide icons
  if (window.lucide) lucide.createIcons();

  // Enter key advances steps
  document.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && e.target.tagName !== 'TEXTAREA') {
      e.preventDefault();
      if (currentStep < 5) nextStep();
    }
  });
});
