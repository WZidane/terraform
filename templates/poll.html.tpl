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

    <div class="max-w-3xl mx-auto p-6 bg-white rounded-lg shadow-md mt-8">
        <div id="admin-actions" class="flex justify-end mb-4"></div>

        <h1 id="title" class="text-3xl font-bold text-gray-800 mb-4 text-center">Chargement...</h1>

        <div id="info" class="flex justify-center items-center mt-5"></div>
        
        <div id="message-erreur" class="text-red-600 mt-4 text-center font-medium"></div>
    </div>

    <div class="max-w-3xl mx-auto mt-8 mb-10">
        <h2 class="text-xl font-bold text-gray-700 mb-4 px-2">Candidats inscrits</h2>
        <div id="applications-list" class="grid grid-cols-1 gap-4">
            <p class="text-gray-500 italic px-2">Chargement des candidatures...</p>
        </div>
    </div>

    <div id="modal" class="fixed inset-0 bg-slate-900/60 backdrop-blur-sm hidden flex items-center justify-center z-50 p-4">
        <div class="bg-white rounded-2xl shadow-xl max-w-md w-full overflow-hidden">
            <div class="px-6 py-4 border-b flex justify-between items-center">
                <h3 class="text-lg font-bold text-gray-800">Candidature</h3>
                <button onclick="toggleModal()" class="text-gray-400 hover:text-gray-600 text-2xl">&times;</button>
            </div>

            <form onsubmit="event.preventDefault(); candidaterPoll();" class="p-6">
                <h1 class="text-center font-semibold mb-5 text-gray-700">Document de campagne (Optionnel)</h1>
                
                <label for="file-upload" class="flex flex-col items-center justify-center w-full h-40 border-2 border-dashed border-gray-300 rounded-xl cursor-pointer bg-gray-50 hover:bg-gray-100 transition">
                    <div id="drop-zone-content" class="flex flex-col items-center justify-center text-center px-4">
                        <svg id="upload-icon" class="w-10 h-10 mb-3 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path></svg>
                        <p id="file-name-display" class="text-sm text-gray-700 font-semibold">Cliquez pour ajouter un fichier</p>
                        <p id="file-subtext" class="text-xs text-gray-500">PDF, JPG, PNG (Max. 10MB)</p>
                    </div>
                    <input id="file-upload" type="file" class="hidden" onchange="handleFileSelect(this)" />
                </label>

                <div class="mt-6 flex flex-col gap-2">
                    <button type="submit" id="submit-btn" class="w-full bg-blue-600 text-white py-2 rounded-lg font-semibold hover:bg-blue-700 shadow-md transition cursor-pointer">
                        Confirmer ma candidature
                    </button>
                    <button type="button" onclick="toggleModal()" class="w-full bg-white text-gray-600 py-2 border border-gray-200 rounded-lg hover:bg-gray-50 transition cursor-pointer">
                        Annuler
                    </button>
                </div>
            </form>
        </div>
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

        const params = new URLSearchParams(window.location.search);

        async function chargerApplications() {
            const listContainer = document.getElementById('applications-list');
            const pollId = params.get("id");
            const API_URL_APPS = `${api_url}/applications/$${pollId}`;

            try {
                const session = await new Promise((resolve, reject) => {
                    cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
                });
                const idToken = session.getIdToken().getJwtToken();

                const response = await fetch(API_URL_APPS, { 
                    headers: { 'Authorization': idToken } 
                });

                if (!response.ok) throw new Error("Erreur candidatures");

                const applications = await response.json();

                if (applications.length === 0) {
                    listContainer.innerHTML = "<p class='text-gray-500 italic px-2'>Aucun candidat pour le moment.</p>";
                    return;
                }

                listContainer.innerHTML = ""; // On vide le loader

                applications.forEach(app => {
                    const card = document.createElement('div');
                    card.className = "bg-white p-4 rounded-xl shadow-sm border border-gray-100 flex justify-between items-center";
                    
                    // On affiche le nom du candidat (ou son ID si le nom n'est pas stocké dans la table application)
                    card.innerHTML = `
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 bg-blue-100 text-blue-600 rounded-full flex items-center justify-center font-bold">
                                $${(app.candidate_name || "C").charAt(0)}
                            </div>
                            <div>
                                <p class="font-semibold text-gray-800">$${app.candidate_name || "Candidat Anonyme"}</p>
                            </div>
                        </div>
                        <div>Votes : $${app.votes || 0}</div>
                        <div class="flex items-center gap-4">
                            <button onclick="voterPourCandidat('$${app.user_id}')" class="bg-green-600 text-white px-4 py-1.5 rounded-lg text-sm font-bold hover:bg-green-700 transition cursor-pointer shadow-sm">
                                Voter pour ce candidat
                            </button>
                            $${app.document_id ? `
                                <button onclick="ouvrirDocument('$${app.document_id}')" class="text-blue-500 hover:underline text-sm font-medium cursor-pointer">
                                    Voir le document
                                </button>
                            ` : '<span class="text-gray-300 text-sm italic">Aucun document</span>'}
                        </div>
                    `;
                    listContainer.appendChild(card);
                });

            } catch (err) {
                console.error(err);
                listContainer.innerHTML = "<p class='text-red-500'>Erreur lors du chargement des candidats.</p>";
            }
        }

        async function chargerPoll() {

            const title = document.getElementById('title');

            const adminActions = document.getElementById('admin-actions');

            const info = document.getElementById('info');

            const API_URL = "${api_url}/polls/" + params.get("id");

            const erreurDiv = document.getElementById("message-erreur");

            erreurDiv.innerText = "";

            const session = await new Promise((resolve, reject) => {
                cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
            });
            const token = session.getIdToken().getJwtToken();

            try {
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

                    chargerApplications()
                    
                    if(poll.is_active) {
                        const btnCandidat = document.createElement('button');
                        btnCandidat.classList = "bg-blue-600 text-white px-6 py-3 rounded-lg shadow hover:bg-blue-700 transition cursor-pointer font-medium";
                        btnCandidat.onclick = toggleModal;
                        btnCandidat.textContent = "Candidatez !";

                        const session = await new Promise((resolve, reject) => {
                            cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
                        });
                        const token = session.getIdToken().getJwtToken();

                        const res = await fetch(`${api_url}/applications/polls/` + params.get("id"), {
                            method: 'GET',
                            headers: { 
                                'Authorization': token,
                                'Content-Type': 'application/json'
                            },
                        });

                        const val = await res.json();

                        if (userId && poll.creator_id === userId) {
                            const btnTerminer = document.createElement('button');
                            btnTerminer.classList = "bg-red-600 text-white px-4 py-2 rounded-md shadow hover:bg-red-700 transition duration-300 text-sm font-bold cursor-pointer";
                            btnTerminer.textContent = "Terminer cette élection";
                    
                            btnTerminer.onclick = () => terminerElection(params.get("id"), token);
                            
                            adminActions.appendChild(btnTerminer);
                        }

                        val == null ? info.appendChild(btnCandidat) : (() => { const p = document.createElement("p"); p.className = "text-gray-500 italic"; p.textContent = "Vous êtes déjà inscrit à cette élection."; info.appendChild(p);})();
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

        async function candidaterPoll() {
            const fileInput = document.getElementById('file-upload');
            const file = fileInput.files[0];
            const btn = document.getElementById('submit-btn');
            let docId = null;

            btn.disabled = true;
            btn.innerText = "Traitement...";

            const session = await new Promise((resolve, reject) => {
                cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
            });
            const token = session.getIdToken().getJwtToken();

            try {
                // 1. Si fichier présent -> Upload S3
                if (file) {
                    docId = Date.now() + "-" + file.name.replace(/\s+/g, '_');
                    const preRes = await fetch(`${api_url}/get-presigned-url?filename=` + docId, {
                        headers: { 'Authorization': token }
                    });
                    const { upload_url } = await preRes.json();

                    await fetch(upload_url, { method: 'PUT', body: file, headers: { 'Content-Type': file.type } });
                }

                // 2. Enregistrement DB
                const res = await fetch(`${api_url}/applications/` + params.get("id"), {
                    method: 'POST',
                    headers: { 
                        'Authorization': token,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ document_id: docId })
                });

                if (res.ok) window.location.href = "poll?id=" + params.get("id");
                else console.log('Error');

            } catch (err) {
                console.log(err);
                btn.disabled = false;
                btn.innerText = "Confirmer ma candidature";
            }
        }

        function toggleModal() {
            document.getElementById('modal').classList.toggle('hidden');
        }

        function handleFileSelect(input) {
            if (input.files[0]) {
                document.getElementById('file-name-display').innerText = input.files[0].name;
                document.getElementById('file-name-display').classList.add('text-blue-600');
                document.getElementById('file-subtext').innerText = "Fichier prêt";
            }
        }

        async function ouvrirDocument(docId) {
            try {
                const session = await new Promise((resolve, reject) => {
                    cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
                });
                const token = session.getIdToken().getJwtToken();

                // On demande l'URL de téléchargement à la Lambda
                const res = await fetch(`${api_url}/get-download-url?document_id=$${docId}`, {
                    headers: { 'Authorization': token }
                });
                
                const data = await res.json();
                
                if (data.download_url) {
                    // Ouvre le document dans un nouvel onglet
                    window.open(data.download_url, '_blank');
                } else {
                    alert("Impossible de récupérer le document.");
                }
            } catch (err) {
                console.error("Erreur doc:", err);
                alert("Erreur lors de l'ouverture du document.");
            }
        }

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

        async function voterPourCandidat(candidateUserId) {
            if (!confirm("Confirmer votre vote ?")) return;
            
            try {
                const session = await new Promise((resolve, reject) => {
                    cognitoUser.getSession((err, session) => err ? reject(err) : resolve(session));
                });
                const token = session.getIdToken().getJwtToken();

                const response = await fetch(`${api_url}/votes`, {
                    method: 'POST',
                    headers: { 
                        'Authorization': token,
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        candidateUserId: candidateUserId,
                        poll_id: params.get("id")
                    })
                });

                if (response.ok) {
                    alert("Vote enregistré !");
                    location.reload(); 
                } else {
                    alert("Erreur lors du vote.");
                }
            } catch (err) {
                console.error("Erreur vote:", err);
            }
        }
    </script>
</body>
</html>