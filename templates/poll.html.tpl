<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    <title>Voteka</title>

    <script>
        window.VotekaConfig = {
            userPoolId: "${user_pool_id}",
            clientId: "${client_id}"
        }
    </script>

    <script src="header.js"></script>
</head>
<body>

    <div class="max-w-3xl mx-auto p-6 bg-white rounded-lg shadow-md mt-8">
        <div id="admin-actions" class="flex justify-end mb-4"></div>

        <h1 id="title" class="text-3xl font-bold text-gray-800 mb-4 text-center">Chargement...</h1>

        <div id="info" class="flex justify-center items-center mt-5"></div>
        
        <div id="message-erreur" class="text-red-600 mt-4 text-center font-medium"></div>
    </div>

    <script>
        const poolData = {
            UserPoolId: window.VotekaConfig.userPoolId, 
            ClientId: window.VotekaConfig.clientId,
        };
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

        let userId = null;

        const cognitoUser = userPool.getCurrentUser();

        if (cognitoUser != null) {
            cognitoUser.getSession((err, session) => {
                if (err || !session.isValid()) {
                    window.location.href = "login"; // Redirection si session morte
                    return;
                }

                const idToken = session.getIdToken().getJwtToken();
                const claims = session.getIdToken().decodePayload();
                userId = claims.sub;
            })
        } else {
            window.location.href = "login";
        }

        async function chargerPoll() {

            const title = document.getElementById('title');

            const adminActions = document.getElementById('admin-actions');

            const info = document.getElementById('info');

            const params = new URLSearchParams(window.location.search);

            const API_URL = "${api_url}/polls/" + params.get("id");
            const API_URL_2 = "${api_url}/application/" + params.get("id") + "/" + userId;

            const erreurDiv = document.getElementById("message-erreur");

            erreurDiv.innerText = "";

            const session = await new Promise((resolve, reject) => {
                cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
            });
            const token = session.getIdToken().getJwtToken();

            try {
                // const response = await fetch(API_URL, { headers: { 'Authorization': localStorage.getItem('token') || '' } });
                const response = await fetch(API_URL, { headers: { 'Authorization': token } });
                if (!response.ok) throw new Error("Erreur lors de l'appel API");

                const poll = await response.json();

                if (!poll) {
                    info.innerHTML = "Poll inconnu.";
                } else {
                    info.innerHTML = "";
                    title.innerHTML = "Élection : " + poll.name;
                    
                    const creatorDiv = document.createElement('p');
                    creatorDiv.className = "text-sm text-gray-500 mb-6 text-center";
                    creatorDiv.textContent = "Créée par : " + (poll.creator_name || "Utilisateur inconnu");
                    title.parentNode.insertBefore(creatorDiv, title.nextSibling);
                    
                    if(poll.is_active) {
                        const ahref = document.createElement('a');
                        ahref.classList = "bg-blue-500 text-center text-white my-3 w-50 p-3 h-min rounded-lg shadow-md hover:bg-white hover:text-blue-500 hover:shadow-lg transition duration-300";
                        ahref.href = "#";
                        ahref.textContent = "Candidatez !";

                        if (userId && poll.creator_id === userId) {
                            const btnTerminer = document.createElement('button');
                            btnTerminer.classList = "bg-red-600 text-white px-4 py-2 rounded-md shadow hover:bg-red-700 transition duration-300 text-sm font-bold";
                            btnTerminer.textContent = "Terminer cette élection";
                    
                            btnTerminer.onclick = () => terminerElection(params.get("id"), token);
                            
                            adminActions.appendChild(btnTerminer);
                        }

                        info.appendChild(ahref);
                    } else {
                        info.innerHTML = "<p class='text-gray-500 italic'>Cette élection est terminée.</p>";
                    }
                }
            } catch (err) {
                console.error(err);
                info.innerHTML = "";
                erreurDiv.innerText = "Impossible de joindre l'API. Vérifie l'URL et les CORS.";
            }
        }

        chargerPoll();

        async function terminerElection(pollId, token) {
            if (!confirm("Es-tu sûr de vouloir clôturer cette élection ?")) return;

            try {
                const response = await fetch("${api_url}/polls/" + pollId, {
                    method: 'PUT',
                    headers: { 
                        'Content-Type': 'application/json',
                        'Authorization': token 
                    },
                    body: JSON.stringify({ is_active: false })
                });

                if (!response.ok) throw new Error("Erreur lors de la clôture");
                
                alert("Élection terminée avec succès !");
                location.reload(); // On recharge pour voir le changement de statut
            } catch (err) {
                alert(err.message);
            }
        }
    </script>
</body>
</html>