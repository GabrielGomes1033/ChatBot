import requests

KIRA_URL = "https://kira-knowledge-intelligence-research.onrender.com/pesquisar"

def perguntar_kira(pergunta: str) -> str:
    try:
        resposta = requests.post(
            KIRA_URL,
            json={"query": pergunta},
            timeout=60
        )

        dados = resposta.json()

        if dados.get("status") == "ok":
            return dados.get("resposta", "A KIRA não retornou resposta.")

        return f"Erro da KIRA: {dados.get('mensagem', 'erro desconhecido')}"

    except Exception as e:
        return f"Não consegui conectar com a KIRA: {e}"