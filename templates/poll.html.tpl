<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.7/dist/amazon-cognito-identity.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@tailwindcss/browser@4"></script>
    <title>Voteka - Détails</title>
    <script>
        window.VotekaConfig = {
            userPoolId: "${user_pool_id}",
            clientId: "${client_id}",
            apiUrl: "${api_url}"
        }
    </script>
    <script src="header.js"></script>
</head>
<body class="bg-gray-50">

    <div class="max-w-3xl mx-auto p-6 bg-white rounded-lg shadow-md mt-8">
        <h1 id="title" class="text-3xl font-bold text-gray-800 mb-4 text-center">Chargement...</h1>
        <div id="info" class="flex justify-center items-center mt-5"></div>
        <div id="message-erreur" class="text-red-600 mt-4 text-center font-medium"></div>
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
        const params = new URLSearchParams(window.location.search);
        let userId = null;

        // --- AUTH CHECK ---
        const userPool = new AmazonCognitoIdentity.CognitoUserPool({
            UserPoolId: window.VotekaConfig.userPoolId,
            ClientId: window.VotekaConfig.clientId
        });
        const cognitoUser = userPool.getCurrentUser();

        if (cognitoUser) {
            cognitoUser.getSession((err, session) => {
                if (err || !session.isValid()) window.location.href = "login";
                userId = session.getIdToken().decodePayload().sub;
            });
        } else {
            window.location.href = "login";
        }

        // --- FUNCTIONS ---
        async function chargerPoll() {
            const pollId = params.get("id");
            try {
                const res = await fetch(`$${window.VotekaConfig.apiUrl}/polls/` + pollId, {
                    headers: { 'Authorization': localStorage.getItem('token') }
                });
                const poll = await res.json();
                document.getElementById('title').innerText = "Élection : " + poll.name;
                document.getElementById('info').innerHTML = `
                    <button onclick="toggleModal()" class="bg-blue-600 text-white px-6 py-3 rounded-lg shadow hover:bg-blue-700 transition cursor-pointer font-medium">
                        Candidatez !
                    </button>`;
            } catch (err) {
                document.getElementById("message-erreur").innerText = "Erreur de chargement du poll.";
            }
        }

        async function candidaterPoll() {
            const fileInput = document.getElementById('file-upload');
            const file = fileInput.files[0];
            const btn = document.getElementById('submit-btn');
            let docId = null;

            btn.disabled = true;
            btn.innerText = "Traitement...";

            try {
                // 1. Si fichier présent -> Upload S3
                if (file) {
                    docId = Date.now() + "-" + file.name.replace(/\s+/g, '_');
                    const preRes = await fetch(`$${window.VotekaConfig.apiUrl}/get-presigned-url?filename=` + docId, {
                        headers: { 'Authorization': localStorage.getItem('token') }
                    });
                    const { upload_url } = await preRes.json();

                    await fetch(upload_url, { method: 'PUT', body: file, headers: { 'Content-Type': file.type } });
                }

                // 2. Enregistrement DB
                const res = await fetch(`$${window.VotekaConfig.apiUrl}/application/` + params.get("id") + "/" + userId, {
                    method: 'POST',
                    headers: { 
                        'Authorization': localStorage.getItem('token'),
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({ document_id: docId })
                });

                if (res.ok) window.location.href = "poll?id=" + params.get("id");
                else throw new Error();

            } catch (err) {
                alert("Erreur lors de l'envoi.");
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

        chargerPoll();
    </script>
</body>
</html>