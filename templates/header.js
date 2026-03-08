const CONFIG = {
    UserPoolId: window.VotekaConfig.userPoolId, 
    ClientId: window.VotekaConfig.clientId
};

function createHeader() {
    const headerHTML = `
        <nav class="flex justify-between items-center p-4 bg-gray-700 text-white mb-5">
            <div class="font-bold text-lg">
                <a href="/" class="text-white no-underline">🗳️ Voteka</a>
            </div>
            <div id="user" class="font-semibold bg-white rounded-lg text-blue-500 px-5 py-3"></div>
            <div class="flex items-center">
                <a href="/" class="text-white no-underline mr-5">Accueil</a>
                <button id="logoutBtn" class="bg-red-600 hover:bg-red-700 text-white font-bold py-2 px-4 rounded cursor-pointer">
                Déconnexion
                </button>
            </div>
        </nav>
    `;  
    document.body.insertAdjacentHTML('afterbegin', headerHTML);

    const poolData = {
        UserPoolId: CONFIG.UserPoolId,
        ClientId: CONFIG.ClientId
    };
    const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
    const cognitoUser = userPool.getCurrentUser();

    if (cognitoUser != null) {
        cognitoUser.getSession((err, session) => {
            if (err || !session.isValid()) {
                window.location.href = "login";
                return;
            }

           cognitoUser.getUserAttributes((err, attributes) => {
                if (err) {
                    console.error("Erreur attributs:", err);
                    return;
                }

                const givenName = attributes.find(attr => attr.Name === "given_name");
                const familyName = attributes.find(attr => attr.Name === "family_name");

                if (givenName || familyName) {
                    document.getElementById('user').textContent = "Bienvenue, " + givenName.Value + " " + familyName.Value + " !";
                }
            });
        })
    } else {
        window.location.href = "login";
    }

    // deconnexion
    document.getElementById("logoutBtn").addEventListener("click", () => {

        if (cognitoUser != null) {
            cognitoUser.signOut();
        }
        
        localStorage.clear();
        window.location.href = "login";
    });
}

document.addEventListener("DOMContentLoaded", createHeader);