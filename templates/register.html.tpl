<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>Voteka - Inscription</title>
  <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
  <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
</head>
<body class="bg-gray-100 flex items-center justify-center h-screen">
  <div class="bg-white p-8 rounded shadow-md w-full max-w-md">
    <h1 class="text-2xl font-bold mb-6 text-center">Créer un compte Voteka</h1>
    
    <form id="signupForm" class="space-y-4">
      <input type="text" id="first_name" placeholder="Prénom" class="w-full p-2 border rounded" required>
      <input type="text" id="last_name" placeholder="Nom" class="w-full p-2 border rounded" required>
      <input type="email" id="email" placeholder="Email" class="w-full p-2 border rounded" required>
      <input type="password" id="password" placeholder="Mot de passe (8+ char, Maj, Chiffre)" class="w-full p-2 border rounded" required>
      <button type="submit" class="w-full bg-blue-500 text-white p-2 rounded hover:bg-blue-600">S'inscrire</button>
    </form>

    <form id="confirmForm" class="hidden space-y-4 mt-4 border-t pt-4">
      <p class="text-sm text-gray-600">Entre le code reçu par email :</p>
      <input type="text" id="confirmCode" placeholder="Code de vérification" class="w-full p-2 border rounded">
      <button type="submit" class="w-full bg-green-500 text-white p-2 rounded hover:bg-green-600">Confirmer mon compte</button>
    </form>

    <p class="mt-4 text-center text-sm">Déjà un compte ? <a href="login.html" class="text-blue-500">Connexion</a></p>
    <p id="message" class="mt-2 text-center text-sm"></p>
  </div>

  <script>
    // Ces variables seront remplacées par Terraform
    const poolData = {
      UserPoolId: "${user_pool_id}",
      ClientId: "${client_id}"
    };

    const userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);
    let userEmail = ""; // Pour garder l'email en mémoire pour la confirmation

    // 1. GESTION DE L'INSCRIPTION
    document.getElementById("signupForm").addEventListener("submit", (e) => {
      e.preventDefault();
      const message = document.getElementById("message");
      
      userEmail = document.getElementById("email").value;
      const password = document.getElementById("password").value;
      const firstName = document.getElementById("first_name").value;
      const lastName = document.getElementById("last_name").value;

      const attributeList = [
        new AmazonCognitoIdentity.CognitoUserAttribute({ Name: "given_name", Value: firstName }),
        new AmazonCognitoIdentity.CognitoUserAttribute({ Name: "family_name", Value: lastName }),
        new AmazonCognitoIdentity.CognitoUserAttribute({ Name: "email", Value: userEmail })
      ];

      userPool.signUp(userEmail, password, attributeList, null, (err, result) => {
        if (err) {
          console.error("Détails de l'erreur Cognito:", err);
          message.textContent = err.message || JSON.stringify(err);
          message.className = "mt-2 text-center text-red-500";
          return;
        }
        message.textContent = "Inscription réussie ! Vérifie tes emails pour le code.";
        message.className = "mt-2 text-center text-blue-500";
        
        // On cache le signup, on montre la confirmation
        document.getElementById("signupForm").classList.add("hidden");
        document.getElementById("confirmForm").classList.remove("hidden");
      });
    });

    // 2. GESTION DE LA CONFIRMATION DU CODE
    document.getElementById("confirmForm").addEventListener("submit", (e) => {
      e.preventDefault();
      const code = document.getElementById("confirmCode").value;
      const message = document.getElementById("message");

      const userData = { Username: userEmail, Pool: userPool };
      const cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

      cognitoUser.confirmRegistration(code, true, (err, result) => {
        if (err) {
          message.textContent = err.message || JSON.stringify(err);
          message.className = "mt-2 text-center text-red-500";
          return;
        }
        message.textContent = "Compte validé ! Redirection vers la connexion...";
        message.className = "mt-2 text-center text-green-500";
        setTimeout(() => window.location.href = "login.html", 2000);
      });
    });
  </script>
</body>
</html>