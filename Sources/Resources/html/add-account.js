// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

const SCREEN_EMAIL = 0;
const SCREEN_IMAP = 1;
const SCREEN_SMTP = 2;
const SCREEN_PROGRESS = 3;
const SCREEN_SUCCESS = 4;
const SCREEN_FAILURE = 5;
const SCREEN_ACCOUNT_TYPE = 6;
const SCREEN_EMAIL_PASSWORD = 7;
const SCREEN_CUSTOM_IMAP = 8;
const SCREEN_CUSTOM_SMTP = 9;
const SCREEN_UPDATE_EMAIL_PASSWORD = 10;

const screenIdTable = [
    'email-template',
    'imap-template',
    'smtp-template',
    'progress-template',
    'success-template',
    'failure-template',
    'account-type-chooser-template',
    'email-password-template',
    'imap-template',
    'smtp-template',
    'update-email-password-template',
];

var state = {};

var loadScreen = function(screen)
{
    var screenId = screenIdTable[screen]
    //var template = document.querySelector('#' + screenId + ' .container');
    var template = document.querySelector('#' + screenId);
    console.log('screen: ' + screenId);
    var node = template.cloneNode(true);
    document.querySelector('#main').innerHTML = '';
    document.querySelector('#main').appendChild(node);
};

var clearScreen = function() {
    document.querySelector('#main').innerHTML = '';
};

var loadScreenProgress = function(description) {
    loadScreen(SCREEN_PROGRESS);
    setupScreenProgress(description);
};

var setupScreenProgress = function(description) {
    document.querySelector('#progress-description').textContent = description;
    var cancelButton = document.querySelector('#cancel');
    cancelButton.addEventListener('click', function(e) {
        var commandInfo = {'command': 'jsCancel'};
        runCommand(commandInfo);
    });
    
    // Show progress.
    var opts = {
        color: '#888',
    }
    var target = document.querySelector('#spinner')
    var spinner = new Spinner(opts).spin(target)
};

var loadScreenSuccess = function(description) {
    loadScreen(SCREEN_SUCCESS);
    setupScreenSuccess(description);
};

var setupScreenSuccess = function(description) {
    document.querySelector('#success-message').textContent = description;
    var closeButton = document.querySelector('#close');
    closeButton.addEventListener('click', function(e) {
        closeWindow();
    });
};

var loadScreenFailure = function(result) {
    loadScreen(SCREEN_FAILURE);
    setupScreenFailure(result);
};

var setupScreenFailure = function(result) {
    document.querySelector('#failed-error-message').textContent = result['error-message'];
    if (result['imap-error'] != null) {
        document.querySelector('#server-error').classList.remove('hidden');
        document.querySelector('#server-error .error-details').textContent = result['imap-error'];
    }
    var closeButton = document.querySelector('#close');
    closeButton.addEventListener('click', function(e) {
        closeWindow();
    });
};

var loadScreenAccountChooser = function() {
    loadScreen(SCREEN_ACCOUNT_TYPE);
    setupScreenAccountChooser();
};

var setupScreenAccountChooser = function() {
    document.querySelector('#gmail').addEventListener('click', function(e) {
        state.provider = 'gmail';
        loadScreenForProvider();
    });
    document.querySelector('#outlook').addEventListener('click', function(e) {
        state.provider = 'outlook';
        loadScreenForProvider();
    });
    document.querySelector('#other-imap').addEventListener('click', function(e) {
        loadScreenEmailPassword();
    });
};

var validateEmailAddress = function() {
    var cancelButton = document.querySelector('#cancel');
    var continueButton = document.querySelector('#continue');
    var previousButton = document.querySelector('#previous');
    var customButton = document.querySelector('#custom');
    
    document.querySelector('#error-message').classList.add('hidden');
    document.querySelector('#email').disabled = true;
    document.querySelector('#display-name').disabled = true;
    document.querySelector('#password').disabled = true;
    customButton.disabled = true;
    previousButton.disabled = true;
    continueButton.disabled = true;
    
    var email = document.querySelector('#email').value;
    var displayName = document.querySelector('#display-name').value;
    var password = document.querySelector('#password').value;
    
    state.email = email;
    state.password = password;
    state.displayName = displayName;

    if (email.indexOf('@') == -1) {
        document.querySelector('#error-message').textContent = 'Please enter a valid email address.';
        document.querySelector('#error-message').classList.remove('hidden');

        customButton.disabled = false;
        previousButton.disabled = false;
        continueButton.disabled = false;
        document.querySelector('#email').disabled = false;
        document.querySelector('#display-name').disabled = false;
        document.querySelector('#password').disabled = false;

        return;
    }

    state.email = email;
    var progressTimer = setTimeout(function() {
        startButtonProgress();
        cancelButton.classList.remove('hidden');
        continueButton.classList.add('hidden');
    }, 500);
    var commandInfo = {'command': 'jsProviderWithEmail', 'email': email};
    runCommand(commandInfo, function(result) {
        clearTimeout(progressTimer);

        if (result['error-message'] != null) {
            document.querySelector('#error-message').textContent = result['error-message'];
            document.querySelector('#error-message').classList.remove('hidden');
            
            customButton.disabled = false;
            previousButton.disabled = false;
            continueButton.disabled = false;
            document.querySelector('#email').disabled = false;
            document.querySelector('#display-name').disabled = false;
            document.querySelector('#password').disabled = false;
            return;
        }

        state.provider = result['provider'];
        state.imapPassword = state.password;
        state.smtpPassword = state.password;
        state.imapHostname = result['imap-hostname'];
        state.smtpHostname = result['smtp-hostname'];
        loadScreenCustomAccount();
    });
};

var startButtonProgress = function() {
    console.log('show button spinner');
    var target = document.querySelector('#button-spinner')
    var opts = {
        lines: 13,
        length: 6,
        width: 3,
        radius: 6,
        color: '#888',
    }
    target.spinner = new Spinner(opts).spin(target)
};

var stopButtonProgress = function() {
    console.log('hide button spinner');
    var target = document.querySelector('#button-spinner')
    if (target.spinner != null) {
        target.spinner.stop();
    }
};

var loadScreenEmailPassword = function() {
    loadScreen(SCREEN_EMAIL_PASSWORD);
    setupScreenEmailPassword();
};

var setupScreenEmailPassword = function() {
    var displayNameElement = document.querySelector('#display-name');
    var emailElement = document.querySelector('#email');
    var passwordElement = document.querySelector('#password');
    if (state.displayName != null) {
        displayNameElement.value = state.displayName;
    }
    if (state.email != null) {
        emailElement.value = state.email;
    }
    if (state.password != null) {
        passwordElement.value = state.password;
    }

    var customButton = document.querySelector('#custom');
    var continueButton = document.querySelector('#continue');
    var previousButton = document.querySelector('#previous');
    var cancelButton = document.querySelector('#cancel');
    continueButton.addEventListener('click', function(e) {
        document.querySelector('#error-message').classList.add('hidden');

        var displayName = displayNameElement.value;
        var password = passwordElement.value;
        var email = emailElement.value;

        if (email.indexOf('@') == -1) {
            document.querySelector('#error-message').textContent = 'Please enter a valid email address.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (password == "") {
            document.querySelector('#error-message').textContent = 'Please enter your password.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }

        state.email = email;
        state.displayName = displayName;
        state.password = password;

        var commandInfo = {
            'command': 'jsCheckExistingEmail',
            'email': email,
        };
        runCommand(commandInfo, function(result) {
            if (result['error-message'] != null) {
                document.querySelector('#error-message').classList.remove('hidden');
                document.querySelector('#error-message').textContent = result['error-message'];
                displayNameElement.focus();
            }
            else {
                validateAndAddKnownAccount();
            }
        });
    });
    previousButton.addEventListener('click', function(e) {
        var displayName = displayNameElement.value;
        var password = passwordElement.value;
        var email = emailElement.value;
        state.email = email;
        state.displayName = displayName;
        state.password = password;

        loadScreenAccountChooser();
    });
    cancelButton.addEventListener('click', function(e) {
        stopButtonProgress();
        var commandInfo = {'command': 'jsCancelValidation'};
        runCommand(commandInfo);

        emailElement.disabled = false;
        passwordElement.disabled = false;
        displayNameElement.disabled = false;
        continueButton.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');
    });
    customButton.addEventListener('click', function(e) {
        state.forceCustom = true;
        validateEmailAddress();
    });
    displayNameElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            emailElement.focus();
        }
    });
    emailElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            passwordElement.focus();
        }
    });
    passwordElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            continueButton.click();
        }
    });
    displayNameElement.focus();
};

var loadScreenUpdateEmailPassword = function() {
    loadScreen(SCREEN_UPDATE_EMAIL_PASSWORD);
    setupScreenUpdateEmailPassword();
};

var setupScreenUpdateEmailPassword = function() {
    var emailElement = document.querySelector('#email');
    var passwordElement = document.querySelector('#password');
    if (state.email != null) {
        emailElement.value = state.email;
    }
    if (state.password != null) {
        passwordElement.value = state.password;
    }

    var continueButton = document.querySelector('#continue');
    var cancelButton = document.querySelector('#cancel');
    continueButton.addEventListener('click', function(e) {
        document.querySelector('#error-message').classList.add('hidden');

        var password = passwordElement.value;
        var email = emailElement.value;
        
        if (email.indexOf('@') == -1) {
            document.querySelector('#error-message').textContent = 'Please enter a valid email address.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (password == "") {
            document.querySelector('#error-message').textContent = 'Please enter your password.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }

        state.password = password;
        validateAndUpdateKnownAccount();
    });
    cancelButton.addEventListener('click', function(e) {
        stopButtonProgress();
        var commandInfo = {'command': 'jsCancelValidation'};
        runCommand(commandInfo);

        passwordElement.disabled = false;
        continueButton.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');
    });
    emailElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            passwordElement.focus();
        }
    });
    passwordElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            continueButton.click();
        }
    });
    passwordElement.focus();
};

var loadScreenForProvider = function() {
    if (state.provider == 'gmail') {
        showOAuth2Authentication();
    }
    else if (state.provider == 'outlook') {
        showOAuth2Authentication();
    }
};

var showOAuth2Authentication = function() {
    console.log(state);
    state.email = state.hintEmail;
    var commandInfo = {'command': 'jsShowOAuth2Authentication', 'hintEmail': state.email, 'provider': state.provider};
    runCommand(commandInfo, function(result) {
        if (result['cancelled']) {
            closeWindow();
        }
        else {
            clearScreen();
            var commandInfo = {'command': 'jsHideOAuth2Authentication', 'hintEmail': state.email};
            runCommand(commandInfo);
            if (result['error-message'] != null) {
                console.log('error');
                loadScreenFailure(result);
            }
            else {
                console.log('token');
                var code = result['code'];
                loadScreenProgress('Adding account...');
                requestOAuth2Token(code);
            }
        }
    });
};

var closeWindow = function() {
    var commandInfo = {'command': 'jsClose'};
    runCommand(commandInfo);
};

var requestOAuth2Token = function(code) {
    var cancelButton = document.querySelector('#cancel');
    cancelButton.addEventListener('click', function(e) {
        var commandInfo = {'command': 'jsCancelValidation'};
        runCommand(commandInfo);
        var commandInfo = {'command': 'jsCancelRequestToken'};
        runCommand(commandInfo);
        closeWindow();
    });

    var commandInfo = {'command': 'jsRequestOAuth2Token', 'code': code, 'provider': state.provider};
    runCommand(commandInfo, function(result) {
        console.log(result);
        console.log(state);
        if (state.email == null) {
            state.email = result['email'];
        }
        var commandInfo = {
            'command': 'jsCheckExistingEmail',
            'email': result['email'],
        };
        runCommand(commandInfo, function(checkEmailResult) {
            if (checkEmailResult['error-message'] != null) {
                loadScreenFailure(checkEmailResult);
                return;
            }
        });
        if (result['email'] != state.email) {
            loadScreenFailure({'error-message': "This account is not the same."})
            return;
        }
        if (result['error-message'] != null) {
            loadScreenFailure(result);
        }
        else {
            state.displayName = result['display-name'];
            state.oauth2Token = result['oauth2-token'];
            state.refreshToken = result['refresh-token'];
            if (state.type == 'update-account') {
                var commandInfo = {'command': 'jsUpdateOAuth2Account', 'email': state.email, 'refresh-token': state.refreshToken};
                runCommand(commandInfo, function(result) {
                    if (result['error-message'] != null) {
                        loadScreenFailure(result);
                    }
                    else {
                        loadScreenSuccess('Your account has been updated successfully.');
                    }
                });
            }
            else {
                validateAndAddGmailAccount();
            }
        }
    });
};

var validateAndAddGmailAccount = function() {
    var commandInfo = {
        'command': 'jsValidateAndAddGmailAccount',
        'email': state.email,
        'display-name': state.displayName,
        'oauth2-token': state.oauth2Token,
        'refresh-token': state.refreshToken,
    };
    runCommand(commandInfo, function(result) {
        if (result['error-message'] != null) {
            loadScreenFailure(result);
        }
        else {
            loadScreenSuccess('Your account has been added successfully.');
        }
    });
};

var validateAndAddKnownAccount = function() {
    var continueButton = document.querySelector('#continue');
    var cancelButton = document.querySelector('#cancel');
    var previousButton = document.querySelector('#previous');
    var customButton = document.querySelector('#custom');
    var emailElement = document.querySelector('#email');
    var displayNameElement = document.querySelector('#display-name');
    var passwordElement = document.querySelector('#password');
    emailElement.blur();
    displayNameElement.blur();
    passwordElement.blur();
    continueButton.classList.add('hidden');
    cancelButton.classList.remove('hidden');

    continueButton.disabled = true;
    previousButton.disabled = true;
    customButton.disabled = true;
    emailElement.disabled = true;
    passwordElement.disabled = true;
    displayNameElement.disabled = true;

    startButtonProgress();
    var commandInfo = {
        'command': 'jsValidateAndAddKnownAccount',
        'email': state.email,
        'display-name': state.displayName,
        'password': state.password,
    };
    runCommand(commandInfo, function(result) {
        stopButtonProgress();
        if (result['error-message'] != null) {
            emailElement.disabled = false;
            passwordElement.disabled = false;
            displayNameElement.disabled = false;
            continueButton.disabled = false;
            previousButton.disabled = false;
            customButton.disabled = false;
            continueButton.classList.remove('hidden');
            cancelButton.classList.add('hidden');

            document.querySelector('#error-message').classList.remove('hidden');
            document.querySelector('#error-message').textContent = result['error-message'];
            if (result['imap-error'] != null) {
                document.querySelector('#server-error').classList.remove('hidden');
                document.querySelector('#server-error .error-details').textContent = result['imap-error'];
            }
            displayNameElement.focus();
        }
        else if (result['result'] == 'custom-provider') {
            state.imapPassword = state.password;
            state.smtpPassword = state.password;
            loadScreenCustomAccount();
        }
        else {
            loadScreenSuccess('Your account has been added successfully.');
        }
    });
};

var validateAndUpdateKnownAccount = function() {
    var continueButton = document.querySelector('#continue');
    var cancelButton = document.querySelector('#cancel');
    var emailElement = document.querySelector('#email');
    var passwordElement = document.querySelector('#password');
    emailElement.blur();
    passwordElement.blur();
    continueButton.classList.add('hidden');
    cancelButton.classList.remove('hidden');

    continueButton.disabled = true;
    passwordElement.disabled = true;

    startButtonProgress();
    var commandInfo = {
        'command': 'jsValidateAndUpdateKnownAccount',
        'email': state.email,
        'display-name': state.displayName,
        'password': state.password,
    };
    runCommand(commandInfo, function(result) {
        stopButtonProgress();
        if (result['error-message'] != null) {
            emailElement.disabled = false;
            passwordElement.disabled = false;
            continueButton.disabled = false;
            continueButton.classList.remove('hidden');
            cancelButton.classList.add('hidden');

            document.querySelector('#error-message').classList.remove('hidden');
            document.querySelector('#error-message').textContent = result['error-message'];
            if (result['imap-error'] != null) {
                document.querySelector('#server-error').classList.remove('hidden');
                document.querySelector('#server-error .error-details').textContent = result['imap-error'];
            }
            passwordElement.focus();
        }
        else if (result['result'] == 'custom-provider') {
            loadScreenSuccess('Unexpected error happened.');
        }
        else {
            loadScreenSuccess('Your account has been updated successfully.');
        }
    });
};

var loadScreenCustomAccount = function() {
    loadScreen(SCREEN_CUSTOM_IMAP);
    setupScreenCustomAccount();
};

var setupScreenCustomAccount = function() {
    var continueButton = document.querySelector('#continue');
    var cancelButton = document.querySelector('#cancel');
    var previousButton = document.querySelector('#previous');

    var hostnameElement = document.querySelector('#hostname');
    var loginElement = document.querySelector('#login');
    var passwordElement = document.querySelector('#password');
    hostnameElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            loginElement.focus();
        }
    });
    loginElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            passwordElement.focus();
        }
    });
    passwordElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            continueButton.click();
        }
    });

    if (state.imapHostname != null) {
        hostnameElement.value = state.imapHostname;
    }
    if (state.imapPassword != null) {
        passwordElement.value = state.imapPassword;
    }
    if (state.imapLogin != null) {
        loginElement.value = state.imapLogin;
    }

    continueButton.addEventListener('click', function(e) {
        document.querySelector('#error-message').classList.add('hidden');

        state.imapHostname = hostnameElement.value;
        state.imapLogin = loginElement.value;
        state.imapPassword = passwordElement.value;

        if (state.imapHostname == "") {
            document.querySelector('#error-message').textContent = 'Please enter the name of the IMAP server.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (state.imapLogin == "") {
            document.querySelector('#error-message').textContent = 'Please enter your login.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (state.imapPassword == "") {
            document.querySelector('#error-message').textContent = 'Please enter your password.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }

        startButtonProgress();
        hostnameElement.disabled = true;
        loginElement.disabled = true;
        passwordElement.disabled = true;
        previousButton.disabled = true;
        continueButton.classList.add('hidden');
        cancelButton.classList.remove('hidden');

        validateCustomIMAPAccount();
    });
    previousButton.addEventListener('click', function(e) {
        state.imapHostname = hostnameElement.value;
        state.imapLogin = loginElement.value;
        state.imapPassword = passwordElement.value;
        loadScreenEmailPassword();
    });
    cancelButton.addEventListener('click', function(e) {
        stopButtonProgress();
        var commandInfo = {'command': 'jsCancelValidation'};
        runCommand(commandInfo);
                                  
        hostnameElement.disabled = false;
        loginElement.disabled = false;
        passwordElement.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');
    });
    if (state.type == 'update-account') {
        previousButton.classList.add('hidden');
    }

    hostnameElement.focus();
};

var validateCustomIMAPAccount = function() {
    var commandInfo = {
        'command': 'jsValidateCustomIMAPAccount',
        'hostname': state.imapHostname,
        'login': state.imapLogin,
        'password': state.imapPassword,
    };
    runCommand(commandInfo, function(result) {
        stopButtonProgress();

        var continueButton = document.querySelector('#continue');
        var cancelButton = document.querySelector('#cancel');
        var previousButton = document.querySelector('#previous');

        var hostnameElement = document.querySelector('#hostname');
        var loginElement = document.querySelector('#login');
        var passwordElement = document.querySelector('#password');

        hostnameElement.disabled = false;
        loginElement.disabled = false;
        passwordElement.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');

        if (result['error-message'] != null) {
            document.querySelector('#error-message').classList.remove('hidden');
            document.querySelector('#error-message').textContent = result['error-message'];
            if (result['imap-error'] != null) {
                document.querySelector('#server-error').classList.remove('hidden');
                document.querySelector('#server-error .error-details').textContent = result['imap-error'];
            }
            hostnameElement.focus();
        }
        else {
            state.imapHostnameResult = result['imap-hostname'];
            state.imapPortResult = result['imap-port'];
            state.imapConnectionTypeResult = result['imap-connection-type'];
            loadScreenCustomSMTP();
        }
    });
};

var loadScreenCustomSMTP = function() {
    loadScreen(SCREEN_CUSTOM_SMTP);
    setupScreenCustomSMTP();
};

var setupScreenCustomSMTP = function() {
    var continueButton = document.querySelector('#continue');
    var cancelButton = document.querySelector('#cancel');
    var previousButton = document.querySelector('#previous');

    var hostnameElement = document.querySelector('#hostname');
    var loginElement = document.querySelector('#login');
    var passwordElement = document.querySelector('#password');
    hostnameElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            loginElement.focus();
        }
    });
    loginElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            passwordElement.focus();
        }
    });
    passwordElement.addEventListener('keypress', function(event) {
        if (event.keyCode == 13) {
            event.preventDefault();
            continueButton.click();
        }
    });

    if (state.smtpHostname != null) {
        hostnameElement.value = state.smtpHostname;
    }
    if (state.smtpPassword != null) {
        passwordElement.value = state.smtpPassword;
    }
    if (state.smtpLogin != null) {
        loginElement.value = state.smtpLogin;
    }

    continueButton.addEventListener('click', function(e) {
        document.querySelector('#error-message').classList.add('hidden');

        state.smtpHostname = hostnameElement.value;
        state.smtpLogin = loginElement.value;
        state.smtpPassword = passwordElement.value;
                                    
        if (state.smtpHostname == "") {
            document.querySelector('#error-message').textContent = 'Please enter the name of the SMTP server.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (state.smtpLogin == "") {
            document.querySelector('#error-message').textContent = 'Please enter your login.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }
        if (state.smtpPassword == "") {
            document.querySelector('#error-message').textContent = 'Please enter your password.';
            document.querySelector('#error-message').classList.remove('hidden');
            return;
        }

        startButtonProgress();
        hostnameElement.disabled = true;
        loginElement.disabled = true;
        passwordElement.disabled = true;
        previousButton.disabled = true;
        continueButton.classList.add('hidden');
        cancelButton.classList.remove('hidden');
                                    
        validateCustomSMTPAccount();
    });
    previousButton.addEventListener('click', function(e) {
        state.smtpHostname = hostnameElement.value;
        state.smtpLogin = loginElement.value;
        state.smtpPassword = passwordElement.value;
        loadScreenCustomAccount();
    });
    cancelButton.addEventListener('click', function(e) {
        stopButtonProgress();
        var commandInfo = {'command': 'jsCancelValidation'};
        runCommand(commandInfo);
                                  
        hostnameElement.disabled = false;
        loginElement.disabled = false;
        passwordElement.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');
    });

    hostnameElement.focus();
};

var validateCustomSMTPAccount = function() {
    var commandInfo = {
        'command': 'jsValidateCustomSMTPAccount',
        'hostname': state.smtpHostname,
        'login': state.smtpLogin,
        'password': state.smtpPassword,
    };
    runCommand(commandInfo, function(result) {
        stopButtonProgress();

        var continueButton = document.querySelector('#continue');
        var cancelButton = document.querySelector('#cancel');
        var previousButton = document.querySelector('#previous');

        var hostnameElement = document.querySelector('#hostname');
        var loginElement = document.querySelector('#login');
        var passwordElement = document.querySelector('#password');

        hostnameElement.disabled = false;
        loginElement.disabled = false;
        passwordElement.disabled = false;
        previousButton.disabled = false;
        continueButton.classList.remove('hidden');
        cancelButton.classList.add('hidden');

        if (result['error-message'] != null) {
            document.querySelector('#error-message').classList.remove('hidden');
            document.querySelector('#error-message').textContent = result['error-message'];
            if (result['imap-error'] != null) {
                document.querySelector('#server-error').classList.remove('hidden');
                document.querySelector('#server-error .error-details').textContent = result['imap-error'];
            }
            hostnameElement.focus();
        }
        else {
            state.smtpHostnameResult = result['smtp-hostname'];
            state.smtpPortResult = result['smtp-port'];
            state.smtpConnectionTypeResult = result['smtp-connection-type'];
            if (state.type == 'update-account') {
                changeCustomAccountCredentials();
                loadScreenSuccess('Your account has been updated successfully.');
            }
            else {
                addCustomAccount();
                loadScreenSuccess('Your account has been added successfully.');
            }
        }
    });
};

var addCustomAccount = function() {
    var commandInfo = {
        'command': 'jsAddCustomAccount',
        'email': state.email,
        'display-name': state.displayName,
        'imap-hostname': state.imapHostnameResult,
        'imap-port': state.imapPortResult,
        'imap-connection-type': state.imapConnectionTypeResult,
        'imap-login': state.imapLogin,
        'imap-password': state.imapPassword,
        'smtp-hostname': state.smtpHostnameResult,
        'smtp-port': state.smtpPortResult,
        'smtp-connection-type': state.smtpConnectionTypeResult,
        'smtp-login': state.smtpLogin,
        'smtp-password': state.smtpPassword,
    };
    runCommand(commandInfo);
};

var changeCustomAccountCredentials = function() {
    var commandInfo = {
        'command': 'jsChangeCustomAccountCredentials',
        'email': state.email,
        'imap-hostname': state.imapHostnameResult,
        'imap-port': state.imapPortResult,
        'imap-connection-type': state.imapConnectionTypeResult,
        'imap-login': state.imapLogin,
        'imap-password': state.imapPassword,
        'smtp-hostname': state.smtpHostnameResult,
        'smtp-port': state.smtpPortResult,
        'smtp-connection-type': state.smtpConnectionTypeResult,
        'smtp-login': state.smtpLogin,
        'smtp-password': state.smtpPassword,
    };
    runCommand(commandInfo);
};

var setup = function() {
    var commandInfo = {'command': 'jsDialogSetup'};
    runCommand(commandInfo, function(result) {
        state.wellKnownIMAPEnabled = result['well-known-imap-enabled'];
        state.customIMAPEnabled = result['custom-imap-enabled'];
        if (result.email == null) {
            loadScreenAccountChooser();
        }
        else {
            state.type = 'update-account';
            state.hintEmail = result.email;
            state.email = result.email;
            state.provider = result['provider-identifier'];
            if ((state.provider == 'gmail') || (state.provider == 'outlook')) {
                loadScreenForProvider();
            }
            else if (state.provider != null) {
                loadScreenUpdateEmailPassword();
            }
            else {
                var properties = result['account-properties']
                if (properties != null) {
                    state.imapHostname = properties['imap-hostname'];
                    state.imapLogin = properties['imap-login'];
                    state.imapPassword = properties['imap-password'];
                    state.smtpHostname = properties['smtp-hostname'];
                    state.smtpLogin = properties['smtp-login'];
                    state.smtpPassword = properties['smtp-password'];
                }
                loadScreenCustomAccount();
            }
        }
    });
};

document.addEventListener("DOMContentLoaded", function(event) {
    setup();
});
