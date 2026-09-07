(() => {
    'use strict';

    const root = document.getElementById('store-ui');
    const lockpickUI = document.getElementById('lockpick-ui');
    const keypadUI = document.getElementById('keypad-ui');
    const marker = document.getElementById('marker');
    const target = document.getElementById('target-zone');
    const status = document.getElementById('lockpick-status');
    const roundLabel = document.getElementById('lockpick-round');
    const totalLabel = document.getElementById('lockpick-total');
    const dots = document.getElementById('round-dots');
    const toolLabel = document.getElementById('lockpick-tool');
    const pinMessage = document.getElementById('pin-message');
    const pinDisplay = document.getElementById('pin-display');

    let mode = null;
    let combo = '';
    let lockpickTimer = null;
    let lockpickRunning = false;
    let markerPosition = 3;
    let markerDirection = 1;
    let round = 1;
    let totalRounds = 4;
    let targetStart = 35;
    let targetWidth = 25;
    let speed = 0.62;
    let advanced = false;
    let submitting = false;

    const resource = () => GetParentResourceName();
    const post = (name, data = {}) => fetch(`https://${resource()}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data)
    }).catch(() => {});

    function setVisible(element, visible) { element.classList.toggle('hidden', !visible); }
    function showRoot() { root.classList.add('visible'); root.setAttribute('aria-hidden', 'false'); }
    function hideRoot() { root.classList.remove('visible'); root.setAttribute('aria-hidden', 'true'); }

    function resetLockpickState() {
        stopLockpick();
        submitting = false;
        round = 1;
        totalRounds = advanced ? 3 : 4;
        markerPosition = 3;
        markerDirection = 1;
        targetStart = 25 + Math.random() * 50;
        targetWidth = advanced ? 31 : 25;
        speed = advanced ? 0.50 : 0.64;
        roundLabel.textContent = round;
        totalLabel.textContent = totalRounds;
        status.textContent = 'Hit SPACE when the marker is green';
        status.className = '';
        toolLabel.textContent = advanced ? 'Advanced lockpick · 3 stages' : 'Standard lockpick · 4 stages';
        dots.innerHTML = Array.from({ length: totalRounds }, (_, i) => `<span class="${i === 0 ? 'active' : ''}"></span>`).join('');
        placeTarget();
        placeMarker();
    }

    function placeTarget() {
        target.style.left = `${targetStart}%`;
        target.style.width = `${targetWidth}%`;
    }
    function placeMarker() { marker.style.left = `${markerPosition}%`; }

    function startLockpick() {
        if (lockpickRunning || submitting || mode !== 'lockpick') return;
        lockpickRunning = true;
        status.textContent = 'Moving… hit the green zone';
        const tick = () => {
            if (!lockpickRunning || mode !== 'lockpick') return;
            markerPosition += markerDirection * speed;
            if (markerPosition >= 97) { markerPosition = 97; markerDirection = -1; }
            if (markerPosition <= 3) { markerPosition = 3; markerDirection = 1; }
            placeMarker();
            lockpickTimer = requestAnimationFrame(tick);
        };
        lockpickTimer = requestAnimationFrame(tick);
    }

    function stopLockpick() {
        lockpickRunning = false;
        if (lockpickTimer !== null) cancelAnimationFrame(lockpickTimer);
        lockpickTimer = null;
    }

    function hitLockpick() {
        if (mode !== 'lockpick' || submitting) return;
        if (!lockpickRunning) startLockpick();
        const inside = markerPosition >= targetStart && markerPosition <= targetStart + targetWidth;
        stopLockpick();

        if (!inside) {
            status.textContent = 'Missed — try the next timing window';
            status.className = 'bad';
            marker.classList.add('shake');
            setTimeout(() => marker.classList.remove('shake'), 280);
            setTimeout(() => { if (mode === 'lockpick' && !submitting) startNewRound(); }, 420);
            return;
        }

        status.textContent = round >= totalRounds ? 'Lock released!' : 'Perfect — pin released';
        status.className = 'good';
        marker.classList.add('success');
        setTimeout(() => marker.classList.remove('success'), 300);

        if (round >= totalRounds) {
            submitting = true;
            setTimeout(() => { post('success'); closeUI(false); }, 350);
            return;
        }

        round += 1;
        setTimeout(startNewRound, 450);
    }

    function startNewRound() {
        if (mode !== 'lockpick' || submitting) return;
        roundLabel.textContent = round;
        dots.querySelectorAll('span').forEach((dot, i) => dot.classList.toggle('active', i === round - 1));
        targetStart = 25 + Math.random() * 50;
        targetWidth = advanced ? 31 : 25;
        markerPosition = 3;
        markerDirection = 1;
        placeTarget();
        placeMarker();
        status.className = '';
        status.textContent = `Stage ${round} · hit the green zone`;
        startLockpick();
    }

    function openLockpick(isAdvanced) {
        mode = 'lockpick';
        advanced = !!isAdvanced;
        combo = '';
        setVisible(keypadUI, false);
        setVisible(lockpickUI, true);
        showRoot();
        resetLockpickState();
        startLockpick();
    }

    function renderPin() {
        pinDisplay.querySelectorAll('span').forEach((el, i) => {
            const filled = i < combo.length;
            el.textContent = filled ? '●' : '•';
            el.classList.toggle('filled', filled);
        });
        pinMessage.textContent = combo.length ? `${combo.length}/4 DIGITS` : 'READY';
    }

    function openKeypad() {
        mode = 'keypad';
        submitting = false;
        combo = '';
        setVisible(lockpickUI, false);
        setVisible(keypadUI, true);
        showRoot();
        keypadUI.classList.remove('invalid', 'success');
        renderPin();
        pinMessage.textContent = 'ENTER 4 DIGITS';
    }

    function submitKeypad() {
        if (mode !== 'keypad' || submitting) return;
        if (combo.length !== 4) {
            pinMessage.textContent = 'ENTER ALL 4 DIGITS';
            keypadUI.classList.remove('invalid');
            void keypadUI.offsetWidth;
            keypadUI.classList.add('invalid');
            return;
        }
        submitting = true;
        pinMessage.textContent = 'VERIFYING CODE…';
        post('tryCombination', { combination: combo });
    }

    function addDigit(digit) {
        if (mode !== 'keypad' || submitting || !/^[0-9]$/.test(String(digit)) || combo.length >= 4) return;
        combo += digit;
        renderPin();
    }
    function backspace() {
        if (mode !== 'keypad' || submitting) return;
        combo = combo.slice(0, -1);
        renderPin();
    }
    function clearKeypad() {
        if (mode !== 'keypad' || submitting) return;
        combo = '';
        renderPin();
        pinMessage.textContent = 'CLEARED — ENTER CODE';
    }

    function closeUI(sendClose = true) {
        const oldMode = mode;
        stopLockpick();
        mode = null;
        submitting = false;
        setVisible(lockpickUI, false);
        setVisible(keypadUI, false);
        hideRoot();
        if (sendClose) {
            if (oldMode === 'lockpick') post('exit');
            if (oldMode === 'keypad') post('padLockClose');
        }
    }

    document.getElementById('lockpick-close').addEventListener('click', () => closeUI());
    document.getElementById('keypad-close').addEventListener('click', () => closeUI());

    document.getElementById('keypad-grid').addEventListener('click', (event) => {
        const button = event.target.closest('button');
        if (!button) return;
        if (button.dataset.key) addDigit(button.dataset.key);
        else if (button.dataset.action === 'clear') clearKeypad();
        else if (button.dataset.action === 'enter') submitKeypad();
    });

    document.addEventListener('keydown', (event) => {
        if (!mode) return;
        if (event.key === 'Escape') { event.preventDefault(); closeUI(); return; }
        if (mode === 'lockpick') {
            if (event.code === 'Space' || event.key === 'Enter') { event.preventDefault(); hitLockpick(); }
            return;
        }
        if (mode === 'keypad') {
            if (/^[0-9]$/.test(event.key)) { event.preventDefault(); addDigit(event.key); }
            else if (event.key === 'Backspace' || event.key === 'Delete') { event.preventDefault(); backspace(); }
            else if (event.key === 'Enter') { event.preventDefault(); submitKeypad(); }
        }
    });

    window.addKeyPadNumber = (button) => addDigit(button?.value || '');
    window.clearForm = clearKeypad;
    window.submitForm = submitKeypad;

    window.addEventListener('message', (event) => {
        const data = event.data || {};
        switch (data.action) {
            case 'ui':
                if (data.toggle) openLockpick(!!data.advanced);
                else closeUI(false);
                break;
            case 'openKeypad': openKeypad(); break;
            case 'closeKeypad': closeUI(false); break;
            case 'safeResult':
                if (mode !== 'keypad') break;
                submitting = false;
                if (data.correct) {
                    pinMessage.textContent = '✓ CODE CORRECT — SAFE UNLOCKED';
                    keypadUI.classList.remove('invalid');
                    keypadUI.classList.add('success');
                    setTimeout(() => closeUI(false), 900);
                } else {
                    pinMessage.textContent = '✕ INCORRECT CODE — TRY AGAIN';
                    keypadUI.classList.remove('success');
                    void keypadUI.offsetWidth;
                    keypadUI.classList.add('invalid');
                }
                break;
            case 'openPadlock': break;
            case 'closePadlock': closeUI(false); break;
        }
    });
})();
