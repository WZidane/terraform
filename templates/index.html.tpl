<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
    <title>Voteka</title>
    <style>
        body { font-family: sans-serif; background: #f4f4f9; padding: 20px; text-align: center; }
        .container { max-width: 500px; margin: auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        ul { list-style: none; padding: 0; }
        li { padding: 10px; border-bottom: 1px solid #eee; color: #555; }
        li:last-child { border-bottom: none; }
        button { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 5px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .error { color: red; margin-top: 10px; }
    </style>

    <script>
        window.VotekaConfig = {
            userPoolId: "${user_pool_id}",
            clientId: "${client_id}"
        }
    </script>

    <script src="header.js"></script>
</head>
<body>

    <div class="container">
        <h1>Élections Voteka</h1>
        <button onclick="chargerPolls()">Actualiser la liste</button>
        
        <ul id="liste-polls"></ul>
        <div id="message-erreur" class="error"></div>
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
                        li.textContent = `ID: $${p.id} - Name: $${p.name || 'N/A'}`;
                        listeUl.appendChild(li);
                    });
                }
            } catch (err) {
                console.error(err);
                listeUl.innerHTML = "";
                erreurDiv.innerText = "Impossible de joindre l'API. Vérifie l'URL et les CORS.";
            }
        }
    </script>
</body>
</html>