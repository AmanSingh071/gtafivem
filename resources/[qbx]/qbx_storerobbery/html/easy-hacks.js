/* Friendly lockpick helper.
 * Keeps the original minigame mechanics/callbacks intact while making the
 * controls clearer and slightly more forgiving for players.
 */
(function () {
    function ensureHelp() {
        if (document.getElementById('easy-hacks-help')) return;

        var help = document.createElement('div');
        help.id = 'easy-hacks-help';
        help.innerHTML =
            '<div class="easy-hacks-title">LOCKPICK</div>' +
            '<div class="easy-hacks-subtitle">Find the sweet spot, then turn the cylinder</div>' +
            '<div class="easy-hacks-row"><span class="easy-hacks-key">MOUSE</span><span>Move the pick</span></div>' +
            '<div class="easy-hacks-row"><span class="easy-hacks-key">W A S D</span><span>or ← ↑ ↓ → to turn</span></div>' +
            '<div class="easy-hacks-row"><span class="easy-hacks-key">ESC</span><span>Cancel</span></div>' +
            '<div class="easy-hacks-tip">Tip: move slowly until the cylinder turns freely.</div>';
        document.body.appendChild(help);
    }

    function showHelp(show) {
        ensureHelp();
        var help = document.getElementById('easy-hacks-help');
        help.classList.toggle('visible', !!show);
    }

    window.addEventListener('message', function (event) {
        var data = event.data || {};
        if (data.action !== 'ui') return;

        if (data.toggle) {
            // Make the original lockpick a little more forgiving without
            // replacing its success/failure logic.
            if (typeof solvePadding !== 'undefined') solvePadding = 7;
            if (typeof maxDistFromSolve !== 'undefined') maxDistFromSolve = 55;
            if (typeof pinDamage !== 'undefined') pinDamage = 10;
            if (typeof pinDamageInterval !== 'undefined') pinDamageInterval = 180;
            showHelp(true);
        } else {
            showHelp(false);
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') return;
        if (typeof CurrentType !== 'undefined' && CurrentType !== 'keypad' && CurrentType !== 'padlock') {
            $.post(`https://${GetParentResourceName()}/exit`);
            showHelp(false);
        }
    });
})();
