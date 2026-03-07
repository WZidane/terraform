<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Voteka - Connexion</title>
  <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
  <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center h-screen">
  <div class="bg-white p-8 rounded shadow-md w-full max-w-md">
    <h1 class="text-2xl font-bold mb-6 text-center">Connexion</h1>
    
    <form id="loginForm" class="space-y-4">
      <input type="email" id="email" placeholder="Email" class="w-full p-2 border rounded" required>
      <input type="password" id="password" placeholder="Mot de passe" class="w-full p-2 border rounded" required>
      <button type="submit" class="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600">Se connecter</button>
    </form>
    
    <p class="mt-4 text-center text-sm">Pas de compte ? <a href="register.html" class="text-blue-500">S'inscrire</a></p>
    <p id="message" class="mt-2 text-center text-red-500 text-sm"></p>
  </div>

  <script>
    // Variables injectées par Terraform
    const poolData = {
      UserPoolId: "${user_pool_id}",
      ClientId: "${client_id}"
    };

    const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

    const cognitoUser = userPool.getCurrentUser();

    if (cognitoUser != null) {
        cognitoUser.getSession((err, session) => {
            if (err || !session.isValid()) {
                window.location.href = "login";
                return;
            } else {
              window.location.href = "/";
            }
        });
    }

    document.getElementById("loginForm").addEventListener("submit", (e) => {
      e.preventDefault();
      
      const email = document.getElementById("email").value;
      const password = document.getElementById("password").value;
      const message = document.getElementById("message");

      const authenticationData = {
        Username: email,
        Password: password,
      };
      const authenticationDetails = new AmazonCognitoIdentity.AuthenticationDetails(authenticationData);

      const userData = {
        Username: email,
        Pool: userPool,
      };
      const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

      cognitoUser.authenticateUser(authenticationDetails, {
        onSuccess: function(result) {
          // On récupère le Token JWT
          const accessToken = result.getAccessToken().getJwtToken();
          
          // On le stock
          localStorage.setItem("token", accessToken);
          
          console.log("Connexion réussie !");
          window.location.href = "index.html"; // Redirige vers l'index ou profil
        },

        onFailure: function(err) {
          console.error(err);
          message.textContent = err.message || "Erreur lors de la connexion";
        },

        mfaRequired: function(codeDeliveryDetails) {
          message.textContent = "MFA requis (non configuré dans ton Terraform)";
        },
      });
    });
  </script>
</body>
</html>