<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    <title>🗳️ Voteka</title>

    <script>
        window.VotekaConfig = {
            userPoolId: "${user_pool_id}",
            clientId: "${client_id}"
        }
    </script>

    <script src="header.js"></script>
</head>
<body>

    <div class="container m-auto">
        <h1>Créer une nouvelle élection</h1>
        <form id="loginForm" class="space-y-4">
            <input type="text" id="name" placeholder="Nom de l'élection" class="w-full p-2 border rounded" maxlength="200" required>
            <button type="submit" class="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600 cursor-pointer">Créer l'élection</button>
        </form>

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

        document.getElementById('loginForm').addEventListener('submit', function(e) {
            e.preventDefault();
            const name = document.getElementById('name').value;
            createPoll(name);
        });

        async function createPoll(name) {
            const API_URL = "${api_url}/polls";

            const cognitoUser = userPool.getCurrentUser();
            if (!cognitoUser) {
                window.location.href = "login";
                return;
            }

            cognitoUser.getSession(async (err, session) => {
                if (err || !session.isValid()) {
                    window.location.href = "login";
                    return;
                }

                const token = session.getIdToken().getJwtToken();

                try {
                    const response = await fetch(API_URL, {
                        method: 'POST',
                        headers: { 
                            'Content-Type': 'application/json',
                            'Authorization': token 
                        },
                        body: JSON.stringify({ name })
                    });

                    if (!response.ok) throw new Error("Erreur lors de l'appel API");
                    const result = await response.json();
                    alert(`Élection créée !`);
                    window.location.href = "/poll?id=" + result.id;
                } catch (err) {
                    console.error(err);
                }
            });
        }
    </script>
</body>
</html>