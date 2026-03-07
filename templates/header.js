const CONFIG = {
    UserPoolId: window.VotekaConfig.userPoolId, 
    ClientId: window.VotekaConfig.clientId
};

function createHeader() {
    const headerHTML = `
        <nav style="display: flex; justify-content: space-between; align-items: center; padding: 15px 30px; background-color: #333; color: white; margin-bottom: 20px;">
            <div style="font-weight: bold; font-size: 1.2rem;">
                <a href="/" style="color: white; text-decoration: none;">🗳️ Voteka</a>
            </div>
            <div>
                <a href="/" style="color: white; text-decoration: none; margin-right: 20px;">Accueil</a>
                <button id="logoutBtn" style="background-color: #ff4d4d; color: white; border: none; padding: 8px 15px; border-radius: 4px; cursor: pointer; font-weight: bold;">
                    Déconnexion
                </button>
            </div>
        </nav>
    `;  
    document.body.insertAdjacentHTML('afterbegin', headerHTML);

    // deconnexion
    document.getElementById("logoutBtn").addEventListener("click", () => {
        const poolData = {
            UserPoolId: CONFIG.UserPoolId,
            ClientId: CONFIG.ClientId
        };
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
        const cognitoUser = userPool.getCurrentUser();

        if (cognitoUser != null) {
            cognitoUser.signOut();
        }
        
        localStorage.clear();
        window.location.href = "login";
    });
}

document.addEventListener("DOMContentLoaded", createHeader);