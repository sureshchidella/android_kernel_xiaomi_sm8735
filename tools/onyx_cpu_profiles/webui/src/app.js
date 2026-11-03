import { exec } from 'kernelsu';
import './style.css';

const MODULE_DIR = '/data/adb/modules/onyx_cpu_profiles';
const status = document.getElementById('status');

async function runProfileCommand(argument) {
  const { errno, stdout, stderr } = await exec(`${MODULE_DIR}/bin/profile.sh ${argument}`);
  if (errno !== 0) throw new Error((stderr || stdout || 'Profile command failed').trim());
  return stdout.trim();
}

async function refreshProfile() {
  try {
    const result = await runProfileCommand('status');
    const state = JSON.parse(result);
    status.textContent = `Selected profile: ${state.label}`;
    document.querySelectorAll('[data-profile]').forEach((button) => {
      const selected = button.dataset.profile === state.profile;
      button.setAttribute('aria-pressed', String(selected));
      button.classList.toggle('selected', selected);
    });
  } catch (error) {
    status.textContent = error.message || 'Could not read the current profile.';
  }
}

document.querySelectorAll('[data-profile]').forEach((button) => {
  button.addEventListener('click', async () => {
    const profile = button.dataset.profile;
    document.querySelectorAll('[data-profile]').forEach((item) => { item.disabled = true; });
    status.textContent = `Applying ${profile === 'battery' ? 'Battery' : 'Gaming'} profile…`;
    try {
      status.textContent = await runProfileCommand(profile);
      await refreshProfile();
    } catch (error) {
      status.textContent = error.message || 'Could not apply the profile.';
    } finally {
      document.querySelectorAll('[data-profile]').forEach((item) => { item.disabled = false; });
    }
  });
});

refreshProfile();
