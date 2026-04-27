import requests

KIRA_URL = "https://kira-knowledge-intelligence-research.onrender.com/pesquisar"

def consultar_kira(pergunta: str):
    try:
        resposta = requests.post(
            KIRA_URL,
            json={"query": pergunta},
            timeout=60
        )

        # Se API caiu ou erro HTTP
        if resposta.status_code != 200:
            return None

        dados = resposta.json()

        if dados.get("status") == "ok":
            return dados.get("resposta")

        # Log opcional
        print(f"[KIRA ERRO]: {dados}")

        return None

    except requests.exceptions.Timeout:
        print("[KIRA]: Timeout na requisição")
        return None

    except Exception as e:
        print(f"[KIRA]: Erro inesperado -> {e}")
        return None