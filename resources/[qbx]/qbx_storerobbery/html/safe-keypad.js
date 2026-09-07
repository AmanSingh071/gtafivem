/* User-friendly safe keypad controller.
 * Loaded after the original UI script so the existing NUI callbacks and server events remain compatible.
 */
(function () {
    function closeKeypadLocal() {
        $('#keypad').css('display', 'none');
    }

    function getValue() {
        return $('#PINbox').val() || '';
    }

    function setValue(value) {
        $('#PINbox').val(String(value).replace(/\D/g, '').slice(0, 4));
    }

    window.addKeyPadNumber = function (button) {
        const value = getValue();
        if (value.length >= 4) return;
        setValue(value + button.value);
    };

    window.clearForm = function () {
        setValue('');
    };

    window.submitForm = function () {
        const value = getValue();
        if (value.length !== 4) {
            $('#PINbox').stop(true, true).css('border-color', '#d56b6b').animate({ opacity: 0.55 }, 70).animate({ opacity: 1 }, 70, function () {
                $('#PINbox').css('border-color', '');
            });
            return;
        }

        closeKeypadLocal();
        $.post(`https://${GetParentResourceName()}/tryCombination`, JSON.stringify({
            combination: value,
        }));
    };

    function buildFriendlyKeypad() {
        if (!$('#PINbox').length) return;

        // The original script sets display:block inline. Force the new flex overlay.
        $('#keypad').css('display', 'flex');
        $('#PINform').attr('draggable', 'false');
        $('#PINbox').attr('readonly', true).attr('inputmode', 'numeric').attr('maxlength', '4');
        $('#PINbox').attr('placeholder', '••••');
    }

    // The original script creates the keypad dynamically. Observe it and enhance it immediately.
    const observer = new MutationObserver(function () {
        if ($('#PINbox').length) buildFriendlyKeypad();
    });

    observer.observe(document.body, { childList: true, subtree: true });

    document.addEventListener('keydown', function (event) {
        if ($('#keypad').css('display') === 'none') return;

        if (/^[0-9]$/.test(event.key)) {
            event.preventDefault();
            if (getValue().length < 4) setValue(getValue() + event.key);
            return;
        }

        if (event.key === 'Backspace' || event.key === 'Delete') {
            event.preventDefault();
            setValue(getValue().slice(0, -1));
            return;
        }

        if (event.key === 'Enter') {
            event.preventDefault();
            window.submitForm();
            return;
        }

        if (event.key === 'Escape') {
            event.preventDefault();
            closeKeypadLocal();
            $.post(`https://${GetParentResourceName()}/padLockClose`);
        }
    });
})();
