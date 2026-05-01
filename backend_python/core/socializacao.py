from datetime import datetime
import json
import os
import random

MEMORIA_SOCIAL = "memoria/aprendizado_social.json"


class SocializacaoIA:
    def __init__(self, nova_agent, kira_agent):
        self.nova = nova_agent
        self.kira = kira_agent

        self.temas = [
            "inteligência artificial",
            "física quântica",
            "mercado financeiro",
            "segurança da informação",
            "programação",
            "automação",
            "empreendedorismo tecnológico",
            "educação com IA",
            "ciência e sociedade",
        ]

        os.makedirs("memoria", exist_ok=True)

        if not os.path.exists(MEMORIA_SOCIAL):
            with open(MEMORIA_SOCIAL, "w", encoding="utf-8") as f:
                json.dump(
                    {"conversas": [], "aprendizados": [], "melhorias_de_resposta": []},
                    f,
                    ensure_ascii=False,
                    indent=4,
                )

    def carregar_memoria(self):
        with open(MEMORIA_SOCIAL, "r", encoding="utf-8") as f:
            return json.load(f)

    def salvar_memoria(self, dados):
        with open(MEMORIA_SOCIAL, "w", encoding="utf-8") as f:
            json.dump(dados, f, ensure_ascii=False, indent=4)

    def escolher_tema(self):
        return random.choice(self.temas)

    def registrar_conversa(self, tema, mensagens):
        memoria = self.carregar_memoria()

        memoria["conversas"].append(
            {"tema": tema, "data": datetime.now().isoformat(), "mensagens": mensagens}
        )

        self.salvar_memoria(memoria)

    def registrar_aprendizado(self, tema, aprendizado):
        memoria = self.carregar_memoria()

        memoria["aprendizados"].append(
            {"tema": tema, "data": datetime.now().isoformat(), "aprendizado": aprendizado}
        )

        self.salvar_memoria(memoria)

    def socializar(self, tema=None, rodadas=4):
        if tema is None:
            tema = self.escolher_tema()

        mensagens = []

        fala_nova = (
            f"KIRA, vamos conversar sobre {tema}. "
            "Quero entender como explicar esse assunto de forma mais humana."
        )

        for rodada in range(rodadas):
            resposta_kira = self.kira.responder(fala_nova)

            mensagens.append({"agente": "KIRA", "rodada": rodada + 1, "mensagem": resposta_kira})

            fala_nova = self.nova.humanizar_resposta(tema, resposta_kira)

            mensagens.append({"agente": "NOVA", "rodada": rodada + 1, "mensagem": fala_nova})

            fala_nova = (
                f"KIRA, avalie esta resposta da NOVA e diga como melhorar "
                f"a clareza, precisão e profundidade:\n\n{fala_nova}"
            )

        aprendizado = self.gerar_aprendizado(tema, mensagens)

        self.registrar_conversa(tema, mensagens)
        self.registrar_aprendizado(tema, aprendizado)

        return {"tema": tema, "conversa": mensagens, "aprendizado": aprendizado}

    def gerar_aprendizado(self, tema, mensagens):
        prompt = (
            f"Com base na conversa sobre {tema}, gere um aprendizado curto "
            "para melhorar futuras respostas da NOVA e da KIRA."
        )

        resumo_kira = self.kira.responder(prompt)

        return resumo_kira
