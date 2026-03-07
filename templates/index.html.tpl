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
        <h1 class="text-3xl font-bold text-gray-800 mb-4 text-center">Élections Voteka</h1>
        
        <ul id="liste-polls" class="divide-y divide-gray-200 flex flex-col justify-center items-center max-h-96 overflow-y-auto"></ul>
        
        <button onclick="javascript:window.location.href='create-poll'">Créer une élection</button>

        <div id="message-erreur" class="text-red-600 mt-4 text-center font-medium"></div>
    </div>

    <script>
        const poolData = {
            UserPoolId: window.VotekaConfig.userPoolId, 
            ClientId: window.VotekaConfig.clientId,
        };
        const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

        const cognitoUser = userPool.getCurrentUser();

        if (cognitoUser != null) {
            cognitoUser.getSession((err, session) => {
                if (err || !session.isValid()) {
                    window.location.href = "login"; // Redirection si session morte
                    return;
                }
            });
        } else {
            window.location.href = "login";
        }

        async function chargerPolls() {
            const API_URL = "${api_url}/polls";

            const listeUl = document.getElementById("liste-polls");
            const erreurDiv = document.getElementById("message-erreur");

            listeUl.innerHTML = "<li>Chargement...</li>";
            erreurDiv.innerText = "";

            try {
                const response = await fetch(API_URL, { headers: { 'Authorization': localStorage.getItem('token') || '' } });
                if (!response.ok) throw new Error("Erreur lors de l'appel API");

                const polls = await response.json();

                if (!Array.isArray(polls) || polls.length === 0) {
                    listeUl.innerHTML = "<li>Aucun poll trouvé dans la base.</li>";
                } else {
                    listeUl.innerHTML = ""; // On vide la liste
                    polls.forEach(p => {
                        const li = document.createElement("li");
                        const ahref = document.createElement("a");

                        ahref.href = `poll?id=$${p.id}`;
                        ahref.textContent = `$${p.name || 'N/A'}`;

                        li.classList = "bg-blue-500 text-center text-white my-3 w-50 p-3 h-min rounded-lg shadow-md hover:bg-white hover:text-blue-500 hover:shadow-lg transition duration-300";
                        li.appendChild(ahref); 
                        listeUl.appendChild(li);
                    });
                }
            } catch (err) {
                console.error(err);
                listeUl.innerHTML = "";
                erreurDiv.innerText = "Impossible de joindre l'API. Vérifie l'URL et les CORS.";
            }
        }

        chargerPolls();
    </script>
</body>
</html>