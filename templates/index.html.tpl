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
        <h1>Candidats Voteka</h1>
        <button onclick="chargerCandidats()">Actualiser la liste</button>
        
        <ul id="liste-candidats">
            <li>Appuyez svp</li>
        </ul>
        <div id="message-erreur" class="error"></div>
    </div>

    <script>
        async function chargerCandidats() {
            const API_URL = "{api_url}"; 
            
            const listeUl = document.getElementById('liste-candidats');
            const erreurDiv = document.getElementById('message-erreur');
            
            listeUl.innerHTML = "<li>Chargement...</li>";
            erreurDiv.innerText = "";

            try {
                const response = await fetch(API_URL);
                if (!response.ok) throw new Error("Erreur lors de l'appel API");
                
                const candidats = await response.json();

                if (candidats.length === 0) {
                    listeUl.innerHTML = "<li>Aucun candidat trouvé dans la base.</li>";
                } else {
                    listeUl.innerHTML = ""; // On vide la liste
                    candidats.forEach(c => {
                        const li = document.createElement('li');
                        // On affiche l'id ou le nom selon ce que tu as mis en DB
                        li.textContent = `ID: ${c.id} ${c.nom ? '- Nom: ' + c.nom : ''}`;
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