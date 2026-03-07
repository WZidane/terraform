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
        <h1 id="title" class="text-3xl font-bold text-gray-800 mb-4 text-center"></h1>

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

            const info = document.getElementById('info');

            const params = new URLSearchParams(window.location.search);

            const API_URL = "${api_url}/polls/" + params.get("id");
            const API_URL_2 = "${api_url}/application/" + params.get("id") + "/" + userId;

            const erreurDiv = document.getElementById("message-erreur");

            erreurDiv.innerText = "";

            try {
                const response = await fetch(API_URL, { headers: { 'Authorization': localStorage.getItem('token') || '' } });
                if (!response.ok) throw new Error("Erreur lors de l'appel API");

                const polls = await response.json();

                if (!polls) {
                    info.innerHTML = "Poll inconnu.";
                } else {
                    info.innerHTML = "";
                    title.innerHTML = "Élection : " + polls.name;

                    const ahref = document.createElement('a');
                    ahref.classList = "bg-blue-500 text-center text-white my-3 w-50 p-3 h-min rounded-lg shadow-md hover:bg-white hover:text-blue-500 hover:shadow-lg transition duration-300";
                    ahref.href = "#";
                    ahref.textContent = "Candidatez !";

                    info.appendChild(ahref);
                }
            } catch (err) {
                console.error(err);
                info.innerHTML = "";
                erreurDiv.innerText = "Impossible de joindre l'API. Vérifie l'URL et les CORS.";
            }
        }

        chargerPoll();
    </script>
</body>
</html>