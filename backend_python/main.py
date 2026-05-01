from datetime import datetime
import traceback
from pathlib import Path
import sys
from urllib.parse import quote_plus
import webbrowser

try:
    from core.kira_api import consultar_kira
except (ImportError, AttributeError):

    def consultar_kira(pergunta: str):
        return None


# =========================
# SOCIALIZAÇÃO / EVOLUÇÃO IA
# =========================
import json
import random


BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

try:
    from core.logger import logger
except (ImportError, AttributeError):

    class _FallbackLogger:
        def warning(self, event: str, **fields) -> None:
            return None

        def error(self, event: str, **fields) -> None:
            return None

    logger = _FallbackLogger()


# =========================
# LOG DE ERRO
# =========================
def registrar_erro(exc):
    logger.error("unhandled_error", exc_info=(type(exc), exc, exc.__traceback__))
    from traceback import format_exception

    caminho = Path("erro_log.txt")
    conteudo = "".join(format_exception(type(exc), exc, exc.__traceback__))
    caminho.write_text(conteudo, encoding="utf-8")
    return caminho


def _log_warning(evento: str, exc: BaseException, **fields) -> None:
    logger.warning(evento, error=str(exc), **fields)


# =========================
# FALLBACK (caso core falhe)
# =========================
def responder(texto, respostas_txt=None, modo="normal", arquivo_aprendizado=None, contexto=None):
    return "Ainda estou em modo básico."


def carregar_aprendizado(_arquivo=None):
    return {}


def detectar_intencao(texto, contexto=None):
    return "desconhecida"


def extrair_nome_usuario(texto):
    return ""


def salvar_aprendizado(pergunta, resposta):
    return 1


def gerar_pesquisa_wikipedia(_):
    return None


def falar(_):
    return False


def executar_agente(objetivo, contexto=None):
    return {"mensagem": "Modo agente indisponível no momento.", "confirmacao_pendente": None}


def processar_confirmacao_agente(texto, contexto=None):
    return None


def eh_pedido_de_agente(texto):
    return False


def carregar_memoria_usuario():
    return {"nome_usuario": "", "idioma_preferido": "pt", "tratamento": "", "topicos_favoritos": []}


def salvar_memoria_usuario(memoria):
    return memoria


def formatar_memoria_usuario(memoria):
    return f"Memória atual: {memoria}"


def registrar_interacao_usuario(entrada, resposta):
    return None


def autenticar_admin(usuario, senha):
    return False


def configurar_admin(usuario, senha):
    return False, "Admin indisponível."


def status_admin():
    return "Admin indisponível."


def explicacao_completa_admin():
    return "Admin indisponível."


def iniciar_monitor_despertador(falar_callback=None, imprimir_callback=None):
    return None


def status_despertador():
    return "Despertador indisponível."


def configurar_despertador(hora, cidade=None, saudacao_nome=None, ativo=None):
    return False, "Despertador indisponível."


def ativar_despertador():
    return "Despertador indisponível."


def desativar_despertador():
    return "Despertador indisponível."


def disparar_despertador(falar_callback=None, imprimir_callback=None, forcar=False):
    return False, "Despertador indisponível."


def iniciar_runtime_fase2(callback_notificacao=None):
    return None


def ligar_fase2(report_interval_min=30):
    return "JARVIS fase 2 indisponível."


def desligar_fase2():
    return "JARVIS fase 2 indisponível."


def enfileirar_tarefa_fase2(objetivo, origem="manual"):
    return False, "JARVIS fase 2 indisponível."


def listar_fila_fase2(limit=12):
    return "JARVIS fase 2 indisponível."


def limpar_fila_fase2():
    return "JARVIS fase 2 indisponível."


def status_fase2():
    return "JARVIS fase 2 indisponível."


def relatorio_agora_fase2():
    return "JARVIS fase 2 indisponível."


def status_backup_drive():
    return "Backup Drive indisponível."


def sincronizar_backup_drive():
    return False, "Backup Drive indisponível."


def restaurar_backup_drive():
    return False, "Backup Drive indisponível."


# =========================
# IMPORTA CORE (se existir)
# =========================
try:
    from core.respostas import (
        responder,
        detectar_intencao,
        extrair_nome_usuario,
        salvar_aprendizado,
        carregar_aprendizado,
    )
    from core.pesquisa import gerar_pesquisa_wikipedia
    from core.voz import falar
    from core.agente import executar_agente, processar_confirmacao_agente, eh_pedido_de_agente
    from core.memoria import (
        carregar_memoria_usuario,
        salvar_memoria_usuario,
        formatar_memoria_usuario,
        registrar_interacao_usuario,
    )
    from core.admin import (
        autenticar_admin,
        configurar_admin,
        status_admin,
        explicacao_completa_admin,
    )
    from core.despertador import (
        iniciar_monitor_despertador,
        status_despertador,
        configurar_despertador,
        ativar_despertador,
        desativar_despertador,
        disparar_despertador,
    )
    from core.jarvis_fase2 import (
        iniciar_runtime as iniciar_runtime_fase2,
        ligar_fase2,
        desligar_fase2,
        enfileirar_tarefa as enfileirar_tarefa_fase2,
        listar_fila as listar_fila_fase2,
        limpar_fila as limpar_fila_fase2,
        status_fase2,
        relatorio_agora as relatorio_agora_fase2,
    )
    from core.backup_drive import (
        status_backup_drive,
        sincronizar_backup_drive,
        restaurar_backup_drive,
    )
except (ImportError, AttributeError) as e:
    registrar_erro(e)

try:
    from api.app import create_app
    import uvicorn

    app = create_app()
except (ImportError, ModuleNotFoundError):
    app = None

try:
    from core.jarvis_chat_bridge import process_pending_tool_confirmation, try_jarvis_tool_flow
except (ImportError, AttributeError) as exc:
    _log_warning("jarvis_chat_bridge_unavailable", exc)

    def process_pending_tool_confirmation(texto, contexto=None, mode="normal"):
        return None

    def try_jarvis_tool_flow(texto, contexto=None, mode="normal"):
        return None


# Migração automática para camada segura de persistência.
for bootstrap_name, bootstrap_fn in (
    ("carregar_memoria_usuario", carregar_memoria_usuario),
    ("carregar_aprendizado", carregar_aprendizado),
    ("status_admin", status_admin),
):
    try:
        bootstrap_fn()
    except (AttributeError, OSError, RuntimeError, TypeError, ValueError) as exc:
        _log_warning("bootstrap_call_failed", exc, target=bootstrap_name)


# =========================
# CONTEXTO
# =========================
memoria_inicial = carregar_memoria_usuario()
contexto = {
    "nome_usuario": memoria_inicial.get("nome_usuario", ""),
    "idioma_preferido": memoria_inicial.get("idioma_preferido", "pt"),
    "tratamento": memoria_inicial.get("tratamento", ""),
    "ultima_intencao": "",
    "confirmacao_pendente": None,
    "jarvis_tool_pending": None,
    "admin_autenticado": False,
    "admin_usuario": "",
    "evolucao_automatica": True,
    "interacoes_desde_evolucao": 0,
    "intervalo_evolucao": 5,
    "ultimos_temas": [],
}


# =========================
# AGENTES NOVA + KIRA + SOCIALIZAÇÃO
# =========================
MEMORIA_SOCIAL = BASE_DIR / "memoria" / "aprendizado_social.json"


class NovaAgent:
    """Adaptador simples para a NOVA participar da socialização."""

    def responder(self, texto: str) -> str:
        try:
            return responder(texto, contexto=contexto)
        except Exception as exc:
            _log_warning("nova_agent_responder_fail", exc)
            return "Posso reformular isso de um jeito mais claro, humano e direto."

    def humanizar_resposta(self, tema: str, resposta_tecnica: str) -> str:
        prompt = (
            "Reescreva a resposta abaixo em português do Brasil, com linguagem humana, objetiva, "
            "bem explicada e fácil de entender. Mantenha a precisão técnica.\n\n"
            f"Tema: {tema}\n\n"
            f"Resposta técnica da KIRA:\n{resposta_tecnica}"
        )
        try:
            texto = responder(prompt, contexto=contexto)
            if texto and texto.strip() and texto.strip() != "Ainda estou em modo básico.":
                return texto
        except Exception as exc:
            _log_warning("nova_agent_humanizar_fail", exc)

        return (
            f"Sobre {tema}:\n\n"
            f"{resposta_tecnica}\n\n"
            "Em resumo: a ideia principal deve ser explicada com clareza, exemplos simples "
            "e sem perder a precisão técnica."
        )


class KiraAgent:
    """Adaptador simples para a KIRA pesquisar, analisar e revisar respostas."""

    def responder(self, texto: str) -> str:
        consulta = texto.strip()
        try:
            wiki = gerar_pesquisa_wikipedia(consulta[:250])
            if wiki:
                titulo = str(wiki.get("titulo", "") or "").strip()
                resumo = str(wiki.get("resumo", "") or "").strip()
                if resumo:
                    return f"{titulo}\n\n{resumo}"
        except Exception as exc:
            _log_warning("kira_agent_wikipedia_fail", exc)

        try:
            resposta = responder(consulta, contexto=contexto)
            if resposta and resposta.strip() and resposta.strip() != "Ainda estou em modo básico.":
                return resposta
        except Exception as exc:
            _log_warning("kira_agent_responder_fail", exc)

        return (
            "Análise KIRA:\n"
            f"Tema solicitado: {consulta}\n\n"
            "1. Conceito central: identificar a ideia principal do tema.\n"
            "2. Explicação técnica: separar definição, funcionamento, aplicações e limites.\n"
            "3. Validação: comparar a resposta com fontes confiáveis quando houver internet/API disponível.\n"
            "4. Resumo final: entregar uma conclusão objetiva para a NOVA transformar em linguagem humana."
        )


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
            "desenvolvimento de software",
            "tecnologia aplicada a negócios",
        ]
        MEMORIA_SOCIAL.parent.mkdir(parents=True, exist_ok=True)
        if not MEMORIA_SOCIAL.exists():
            self.salvar_memoria(
                {
                    "conversas": [],
                    "aprendizados": [],
                    "melhorias_de_resposta": [],
                    "evolucao_automatica": {"ativa": True, "intervalo": 5},
                }
            )

    def carregar_memoria(self):
        try:
            return json.loads(MEMORIA_SOCIAL.read_text(encoding="utf-8"))
        except Exception:
            return {"conversas": [], "aprendizados": [], "melhorias_de_resposta": []}

    def salvar_memoria(self, dados):
        MEMORIA_SOCIAL.write_text(json.dumps(dados, ensure_ascii=False, indent=4), encoding="utf-8")

    def escolher_tema(self):
        return random.choice(self.temas)

    def registrar_conversa(self, tema, mensagens):
        memoria = self.carregar_memoria()
        memoria.setdefault("conversas", []).append(
            {
                "tema": tema,
                "data": datetime.now().isoformat(),
                "mensagens": mensagens,
            }
        )
        self.salvar_memoria(memoria)

    def registrar_aprendizado(self, tema, aprendizado, origem="manual"):
        memoria = self.carregar_memoria()
        memoria.setdefault("aprendizados", []).append(
            {
                "tema": tema,
                "origem": origem,
                "data": datetime.now().isoformat(),
                "aprendizado": aprendizado,
            }
        )
        memoria.setdefault("melhorias_de_resposta", []).append(
            {
                "tema": tema,
                "regra": aprendizado,
                "data": datetime.now().isoformat(),
            }
        )
        self.salvar_memoria(memoria)

    def socializar(self, tema=None, rodadas=3, origem="manual"):
        if tema is None or not str(tema).strip():
            tema = self.escolher_tema()
        tema = str(tema).strip()
        mensagens = []
        fala_nova = (
            f"KIRA, vamos socializar sobre {tema}. "
            "Traga uma visão técnica, objetiva e útil para melhorarmos nossas futuras respostas."
        )
        for rodada in range(max(1, int(rodadas))):
            resposta_kira = self.kira.responder(fala_nova)
            mensagens.append({"agente": "KIRA", "rodada": rodada + 1, "mensagem": resposta_kira})

            resposta_nova = self.nova.humanizar_resposta(tema, resposta_kira)
            mensagens.append({"agente": "NOVA", "rodada": rodada + 1, "mensagem": resposta_nova})

            fala_nova = (
                "KIRA, avalie a resposta da NOVA abaixo. Diga como melhorar clareza, precisão, "
                f"profundidade e objetividade.\n\n{resposta_nova}"
            )

        aprendizado = self.gerar_aprendizado(tema, mensagens)
        self.registrar_conversa(tema, mensagens)
        self.registrar_aprendizado(tema, aprendizado, origem=origem)
        return {"tema": tema, "conversa": mensagens, "aprendizado": aprendizado}

    def gerar_aprendizado(self, tema, mensagens):
        conversa_curta = "\n".join(
            f"{m['agente']}: {str(m['mensagem'])[:600]}" for m in mensagens[-4:]
        )
        prompt = (
            f"Com base nesta conversa sobre {tema}, gere uma regra curta de melhoria para futuras respostas. "
            "A regra deve ajudar a NOVA a responder melhor e a KIRA a pesquisar melhor.\n\n"
            f"{conversa_curta}"
        )
        try:
            resumo = self.kira.responder(prompt)
            if resumo and resumo.strip():
                return resumo.strip()
        except Exception as exc:
            _log_warning("socializacao_aprendizado_fail", exc)
        return (
            f"Ao responder sobre {tema}, combinar explicação objetiva, exemplo prático, "
            "precisão técnica e conclusão curta."
        )


try:
    nova_agent = NovaAgent()
    kira_agent = KiraAgent()
    social_agent = SocializacaoIA(nova_agent, kira_agent)
except Exception as exc:
    registrar_erro(exc)
    nova_agent = None
    kira_agent = None
    social_agent = None


def executar_socializacao(tema=None, rodadas=3, mostrar_conversa=True, origem="manual"):
    if not social_agent:
        print("NOVA: Módulo de socialização indisponível.")
        return None
    resultado = social_agent.socializar(tema=tema, rodadas=rodadas, origem=origem)
    if mostrar_conversa:
        print("\n🤖 === CONVERSA NOVA ↔ KIRA ===\n")
        for msg in resultado.get("conversa", []):
            print(f"{msg['agente']}: {msg['mensagem']}\n")
    print("🧠 === APRENDIZADO GERADO ===\n")
    print(resultado.get("aprendizado", "Nenhum aprendizado gerado."))
    return resultado


def comando_social(texto):
    tema = texto.replace("/social", "", 1).strip()
    try:
        executar_socializacao(
            tema=tema if tema else None, rodadas=3, mostrar_conversa=True, origem="manual"
        )
    except Exception as exc:
        registrar_erro(exc)
        print("NOVA: Erro ao executar socialização.")


def comando_evolucao(texto):
    partes = texto.strip().split(maxsplit=2)
    acao = partes[1].lower() if len(partes) >= 2 else "status"

    if acao in ("on", "ligar", "ativar"):
        contexto["evolucao_automatica"] = True
        print(
            "NOVA: Evolução automática ativada. Vou socializar com a KIRA a cada ciclo de aprendizado."
        )
        return

    if acao in ("off", "desligar", "pausar"):
        contexto["evolucao_automatica"] = False
        print("NOVA: Evolução automática pausada.")
        return

    if acao == "status":
        estado = "ativa" if contexto.get("evolucao_automatica") else "pausada"
        print(
            f"NOVA: Evolução automática está {estado}. "
            f"Intervalo: {contexto.get('intervalo_evolucao', 5)} interações. "
            f"Contador atual: {contexto.get('interacoes_desde_evolucao', 0)}."
        )
        return

    if acao == "intervalo":
        if len(partes) < 3:
            print("NOVA: Use /evolucao intervalo <numero>")
            return
        try:
            intervalo = max(1, int(partes[2]))
            contexto["intervalo_evolucao"] = intervalo
            print(f"NOVA: Intervalo de evolução alterado para {intervalo} interações.")
        except ValueError:
            print("NOVA: Informe um número válido.")
        return

    if acao in ("agora", "rodar"):
        tema = partes[2] if len(partes) >= 3 else None
        executar_socializacao(tema=tema, rodadas=2, mostrar_conversa=True, origem="manual_agora")
        contexto["interacoes_desde_evolucao"] = 0
        return

    print("NOVA: Use /evolucao status | on | off | intervalo <n> | agora [tema]")


def evolucao_automatica_pos_resposta(entrada_usuario, resposta_nova):
    if not contexto.get("evolucao_automatica", False):
        return
    if not social_agent:
        return
    if entrada_usuario.startswith("/"):
        return

    contexto["interacoes_desde_evolucao"] = contexto.get("interacoes_desde_evolucao", 0) + 1
    contexto.setdefault("ultimos_temas", []).append(entrada_usuario[:180])
    contexto["ultimos_temas"] = contexto["ultimos_temas"][-5:]

    intervalo = int(contexto.get("intervalo_evolucao", 5) or 5)
    if contexto["interacoes_desde_evolucao"] < intervalo:
        return

    tema = " | ".join(contexto.get("ultimos_temas", [])[-3:]) or entrada_usuario
    try:
        print("\nNOVA: Evolução automática iniciada entre NOVA e KIRA...")
        resultado = executar_socializacao(
            tema=tema,
            rodadas=2,
            mostrar_conversa=False,
            origem="automatica",
        )
        contexto["interacoes_desde_evolucao"] = 0
        if resultado:
            registrar_interacao_usuario("/evolucao automatica", resultado.get("aprendizado", ""))
    except Exception as exc:
        registrar_erro(exc)
        print("NOVA: Não consegui concluir a evolução automática desta vez.")


# =========================
# FUNÇÕES
# =========================
def saudacao():
    if contexto["nome_usuario"]:
        return f"Oi, {contexto['nome_usuario']}! Eu sou a NOVA."
    return "Oi! Eu sou a NOVA."


def sincronizar_memoria():
    memoria = carregar_memoria_usuario()
    memoria["nome_usuario"] = contexto.get("nome_usuario", "")
    memoria["idioma_preferido"] = contexto.get("idioma_preferido", "pt")
    memoria["tratamento"] = contexto.get("tratamento", "")
    salvar_memoria_usuario(memoria)


def comando_ensinar(texto):
    try:
        _, conteudo = texto.split(" ", 1)
        pergunta, resposta = conteudo.split("=", 1)

        pergunta = pergunta.strip()
        resposta = resposta.strip()

        total = salvar_aprendizado(pergunta, resposta)

        print(f"NOVA: Aprendi! ({total} respostas salvas)")
    except ValueError:
        print("NOVA: Use /ensinar pergunta = resposta")


def comando_google(texto):
    try:
        _, consulta = texto.split(" ", 1)
        url = f"https://www.google.com/search?q={quote_plus(consulta)}"

        wiki = gerar_pesquisa_wikipedia(consulta)

        if wiki:
            titulo = str(wiki.get("titulo", "") or "").strip()
            resumo = str(wiki.get("resumo", "") or "").strip()
            print(f"\nNOVA: {titulo}\n{resumo}".strip())
        else:
            print("NOVA: Abrindo Google...")
            webbrowser.open(url)

    except ValueError:
        print("NOVA: Use /google algo")


def comando_nome(texto):
    try:
        _, nome = texto.split(" ", 1)
        contexto["nome_usuario"] = nome.strip().title()
        sincronizar_memoria()
        resposta = f"Beleza, vou te chamar de {contexto['nome_usuario']}"
        print(f"NOVA: {resposta}")
        registrar_interacao_usuario(texto, resposta)
    except ValueError:
        print("NOVA: Use /nome SeuNome")


def comando_memoria():
    memoria = carregar_memoria_usuario()
    resposta = formatar_memoria_usuario(memoria)
    print("NOVA:\n" + resposta)
    registrar_interacao_usuario("/memoria", resposta)


def comando_agente(texto):
    texto_norm = texto.lower()
    if texto_norm.startswith("/nova"):
        objetivo = texto[5:].strip(" :")
    elif texto_norm.startswith("/agente"):
        objetivo = texto[7:].strip(" :")
    else:
        objetivo = texto.strip()
    if not objetivo:
        print(
            "NOVA: Use /nova <objetivo>. Exemplo: /nova organize meu dia: estudar, mercado, treino"
        )
        return

    resultado = executar_agente(objetivo, contexto=contexto)
    contexto["confirmacao_pendente"] = resultado.get("confirmacao_pendente")
    sincronizar_memoria()
    resposta = resultado.get("mensagem", "Plano executado.")
    print("NOVA:", resposta)
    registrar_interacao_usuario(texto, resposta)


def comando_admin(texto):
    partes = texto.strip().split()
    if len(partes) == 1:
        print(
            "NOVA: Comandos admin -> /admin login <usuario> <senha> | /admin logout | "
            "/admin explicar | /admin status | /admin configurar <usuario> <senha>"
        )
        return

    acao = partes[1].lower()

    if acao == "login":
        if len(partes) < 4:
            print("NOVA: Use /admin login <usuario> <senha>")
            return
        usuario = partes[2]
        senha = partes[3]
        if autenticar_admin(usuario, senha):
            contexto["admin_autenticado"] = True
            contexto["admin_usuario"] = usuario
            print(f"NOVA: Login admin confirmado para {usuario}.")
        else:
            print("NOVA: Credenciais de admin inválidas.")
        return

    if acao == "logout":
        contexto["admin_autenticado"] = False
        contexto["admin_usuario"] = ""
        print("NOVA: Sessão admin encerrada.")
        return

    if acao == "status":
        print("NOVA:\n" + status_admin())
        return

    if acao == "configurar":
        if not contexto.get("admin_autenticado"):
            print("NOVA: Faça login admin antes de configurar credenciais.")
            return
        if len(partes) < 4:
            print("NOVA: Use /admin configurar <usuario> <senha>")
            return
        ok, mensagem = configurar_admin(partes[2], partes[3])
        print(f"NOVA: {mensagem}")
        if ok:
            contexto["admin_usuario"] = partes[2]
        return

    if acao == "explicar":
        if not contexto.get("admin_autenticado"):
            print("NOVA: Comando restrito. Faça /admin login primeiro.")
            return
        print("NOVA:\n" + explicacao_completa_admin())
        return

    if acao == "despertador":
        if not contexto.get("admin_autenticado"):
            print("NOVA: Comando restrito. Faça /admin login primeiro.")
            return

        if len(partes) == 2:
            print(
                "NOVA: /admin despertador status | /admin despertador ligar HH:MM [cidade] [nome] | "
                "/admin despertador desligar | /admin despertador testar"
            )
            return

        sub = partes[2].lower()
        if sub == "status":
            print("NOVA:\n" + status_despertador())
            return

        if sub == "ligar":
            if len(partes) < 4:
                print("NOVA: Use /admin despertador ligar HH:MM [cidade] [nome]")
                return
            hora = partes[3]
            cidade = None
            nome = None
            if len(partes) >= 5:
                cidade = partes[4]
            if len(partes) >= 6:
                nome = " ".join(partes[5:])
            ok, msg = configurar_despertador(
                hora=hora, cidade=cidade, saudacao_nome=nome, ativo=True
            )
            if ok:
                iniciar_monitor_despertador(
                    falar_callback=falar,
                    imprimir_callback=lambda m: print("NOVA (despertador):", m),
                )
            print("NOVA:", msg)
            return

        if sub == "desligar":
            print("NOVA:", desativar_despertador())
            return

        if sub == "testar":
            _, msg = disparar_despertador(
                falar_callback=falar,
                imprimir_callback=lambda m: print("NOVA (despertador):", m),
                forcar=True,
            )
            print("NOVA:", "Teste de despertador executado.")
            return

        print("NOVA: Subcomando de despertador não reconhecido.")
        return

    if acao == "jarvis2":
        if not contexto.get("admin_autenticado"):
            print("NOVA: Comando restrito. Faça /admin login primeiro.")
            return

        if len(partes) < 3:
            print(
                "NOVA: /admin jarvis2 status | /admin jarvis2 ligar [intervalo_min] | /admin jarvis2 desligar | "
                "/admin jarvis2 enfileirar <objetivo> | /admin jarvis2 fila | /admin jarvis2 limpar | "
                "/admin jarvis2 relatorio"
            )
            return

        sub = partes[2].lower()
        if sub == "status":
            print("NOVA:\n" + status_fase2())
            return
        if sub == "ligar":
            intervalo = 30
            if len(partes) >= 4:
                try:
                    intervalo = int(partes[3])
                except ValueError:
                    intervalo = 30
            iniciar_runtime_fase2(
                callback_notificacao=lambda m: (print("NOVA (JARVIS):", m), falar(m))
            )
            print("NOVA:", ligar_fase2(intervalo))
            return
        if sub == "desligar":
            print("NOVA:", desligar_fase2())
            return
        if sub == "enfileirar":
            if len(partes) < 4:
                print("NOVA: Use /admin jarvis2 enfileirar <objetivo>")
                return
            objetivo = " ".join(partes[3:])
            ok, msg = enfileirar_tarefa_fase2(objetivo, origem="admin_terminal")
            print("NOVA:", msg)
            return
        if sub == "fila":
            print("NOVA:\n" + listar_fila_fase2())
            return
        if sub == "limpar":
            print("NOVA:", limpar_fila_fase2())
            return
        if sub == "relatorio":
            print("NOVA:\n" + relatorio_agora_fase2())
            return
        print("NOVA: Subcomando jarvis2 não reconhecido.")
        return

    if acao == "drivebackup":
        if not contexto.get("admin_autenticado"):
            print("NOVA: Comando restrito. Faça /admin login primeiro.")
            return
        if len(partes) < 3:
            print(
                "NOVA: /admin drivebackup status | /admin drivebackup sincronizar | /admin drivebackup restaurar"
            )
            return
        sub = partes[2].lower()
        if sub == "status":
            print("NOVA:", status_backup_drive())
            return
        if sub == "sincronizar":
            ok, msg = sincronizar_backup_drive()
            print("NOVA:", msg)
            return
        if sub == "restaurar":
            ok, msg = restaurar_backup_drive()
            print("NOVA:", msg)
            return
        print("NOVA: Subcomando drivebackup não reconhecido.")
        return

    print("NOVA: Comando admin não reconhecido.")


# =========================
# LOOP PRINCIPAL
# =========================
def main():
    print("🤖 NOVA (modo terminal)")
    print(saudacao())
    print("Digite 'sair' para encerrar\n")

    iniciar_monitor_despertador(
        falar_callback=falar,
        imprimir_callback=lambda m: print("NOVA (despertador):", m),
    )
    iniciar_runtime_fase2(callback_notificacao=lambda m: (print("NOVA (JARVIS):", m), falar(m)))

    while True:
        user = input("Você: ").strip()

        if not user:
            continue

        if contexto.get("confirmacao_pendente"):
            resposta_confirmacao = processar_confirmacao_agente(user, contexto=contexto)
            if resposta_confirmacao:
                print("NOVA:", resposta_confirmacao)
                registrar_interacao_usuario(user, resposta_confirmacao)
                continue

        tool_confirmacao = process_pending_tool_confirmation(user, contexto, mode="normal")
        if isinstance(tool_confirmacao, dict) and tool_confirmacao.get("handled"):
            resposta = str(tool_confirmacao.get("reply", ""))
            print("NOVA:", resposta)
            registrar_interacao_usuario(user, resposta)
            continue

        if user.lower() == "sair":
            sincronizar_memoria()
            print("NOVA: Até mais! 👋")
            break

        # =========================
        # COMANDOS
        # =========================
        if user.startswith("/social"):
            comando_social(user)
            continue

        if user.startswith("/evolucao"):
            comando_evolucao(user)
            continue

        if user.startswith("/ensinar"):
            comando_ensinar(user)
            continue

        if user.startswith("/google"):
            comando_google(user)
            continue

        if user.startswith("/nome"):
            comando_nome(user)
            continue

        if user.startswith("/memoria"):
            comando_memoria()
            continue

        if user.startswith("/nova") or user.startswith("/agente"):
            comando_agente(user)
            continue

        if user.startswith("/admin"):
            comando_admin(user)
            continue

        if eh_pedido_de_agente(user):
            comando_agente(user)
            continue

        # =========================
        # CONVERSA NORMAL
        # =========================
        nome = extrair_nome_usuario(user)
        if nome:
            contexto["nome_usuario"] = nome
            sincronizar_memoria()

        jarvis_tool = try_jarvis_tool_flow(user, contexto, mode="normal")
        if isinstance(jarvis_tool, dict) and jarvis_tool.get("reply"):
            resposta = str(jarvis_tool.get("reply", ""))
            print("NOVA:", resposta)
            registrar_interacao_usuario(user, resposta)
            continue

        intencao = detectar_intencao(user, contexto)
        contexto["ultima_intencao"] = intencao

        # Comando direto para consultar a KIRA:
        # Exemplo: kira O que é inteligência artificial?
        if user.lower().startswith("kira "):
            pergunta_kira = user[5:].strip()
            resposta = consultar_kira(pergunta_kira) or "Não consegui consultar a KIRA agora."
        else:
            # Primeiro tenta responder localmente
            resposta = responder(user, contexto=contexto)

            # Se a resposta local for fraca, chama a KIRA no Render
            resposta_fraca = (
                not resposta
                or "modo básico" in resposta.lower()
                or len(resposta.strip()) < 20
                or intencao == "desconhecida"
            )

            if resposta_fraca:
                resposta_kira = consultar_kira(user)

                if resposta_kira:
                    resposta = resposta_kira

        print("NOVA:", resposta)
        registrar_interacao_usuario(user, resposta)
        evolucao_automatica_pos_resposta(user, resposta)

        try:
            falar(resposta)
        except (OSError, RuntimeError, ValueError) as exc:
            _log_warning("cli_tts_fail", exc)


# =========================
# START
# =========================
if __name__ == "__main__":
    main()
