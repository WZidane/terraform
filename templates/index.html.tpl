<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
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
</head>
<body>

    <div class="container">
        <h1>Polls Voteka</h1>
        <button onclick="chargerPolls()">Actualiser la liste</button>
        
        <ul id="liste-polls">
            <li>Appuyez svp</li>
        </ul>
        <div id="message-erreur" class="error"></div>
    </div>

    <script>
        // Vérifie présence du token Cognito (stocké en localStorage)
        if (!localStorage.getItem('token')) {
            window.location.href = "login.html";
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