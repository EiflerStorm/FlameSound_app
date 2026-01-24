// Este código é escrito em JavaScript (Node.js) e é implementado no ambiente das Cloud Functions.

// 1. Importar as ferramentas necessárias
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios"); // Para fazer pedidos a APIs externas

// Inicializar a aplicação de administração do Firebase
admin.initializeApp();

// --- Configuração da API do Spotify ---
// É necessário obter estas credenciais no painel de programador do Spotify: https://developer.spotify.com/dashboard
const SPOTIFY_CLIENT_ID = "06972f51bfa64833a07561e41696d69b";
const SPOTIFY_CLIENT_SECRET = "5678bfe28ab543e5841a80894b982edd";

// Função para obter o token de acesso do Spotify
const getSpotifyToken = async () => {
  const authString = Buffer.from(`${SPOTIFY_CLIENT_ID}:${SPOTIFY_CLIENT_SECRET}`).toString("base64");
  
  try {
    const response = await axios.post("https://accounts.spotify.com/api/token", 
      "grant_type=client_credentials", {
      headers: {
        "Authorization": `Basic ${authString}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
    });
    return response.data.access_token;
  } catch (error) {
    console.error("Erro ao obter o token do Spotify:", error.response ? error.response.data : error.message);
    return null;
  }
};


// 2. Definir a nossa Cloud Function
//    Ela será acionada (.onCreate) sempre que um novo documento for criado
//    em 'musicas/{musicaId}'
exports.findArtistCover = functions.firestore
  .document("songs/{songId}")
  .onCreate(async (snap, context) => {
    // 3. Obter os dados da música que foi acabada de adicionar
    const songData = snap.data();
    const artist = songData.artist;

    if (!artist) {
      console.log("Nome do artista não encontrado.");
      return null;
    }

    console.log(`A procurar imagem para o artista: ${artist}`);

    // 4. Obter o token de acesso do Spotify
    const token = await getSpotifyToken();
    if (!token) {
      console.error("Não foi possível obter o token do Spotify. A função será encerrada.");
      return null;
    }

    // 5. Usar a API de pesquisa do Spotify para encontrar o artista
    const searchUrl = `https://api.spotify.com/v1/search?q=${encodeURIComponent(artist)}&type=artist&limit=1`;

    try {
      const response = await axios.get(searchUrl, {
        headers: {
          "Authorization": `Bearer ${token}`,
        },
      });

      // 6. Verificar se encontrámos o artista e se ele tem imagens
      const artists = response.data.artists.items;
      if (artists && artists.length > 0 && artists[0].images && artists[0].images.length > 0) {
        // Pegar o URL da primeira imagem (geralmente a de maior resolução)
        const imageUrl = artists[0].images[0].url;
        console.log(`Imagem encontrada: ${imageUrl}`);

        // 7. Atualizar o documento no Firestore com o URL da capa
        return snap.ref.update({ urlCover: imageUrl });
      } else {
        console.log(`Nenhuma imagem encontrada para ${artist} no Spotify.`);
        return null;
      }
    } catch (error) {
      console.error("Erro ao contactar a API do Spotify:", error.response ? error.response.data : error.message);
      return null;
    }
  });
