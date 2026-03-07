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
        <h1>Créer une nouvelle élection</h1>
        <form id="loginForm" class="space-y-4">
            <input type="text" id="name" placeholder="Nom de l'élection" class="w-full p-2 border rounded" maxlength="200" required>
            <button type="submit" class="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600">Créer l'élection</button>
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
            
            // Récupération PROPRE du token depuis la session Cognito
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
                    alert(`Élection créée ! ID: $${result.id}`);
                } catch (err) {
                    console.error(err);
                }
            });
        }
    </script>
</body>
</html>