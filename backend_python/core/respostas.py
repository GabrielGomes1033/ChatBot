# Núcleo de linguagem da NOVA.
# Este módulo detecta intenções, carrega respostas por modo e gerencia o aprendizado.
from datetime import datetime
from pathlib import Path
import random
import re
import unicodedata

from core.aprendizado_admin import (
    buscar_resposta_aprendida as buscar_resposta_aprendida_v2,
    carregar_aprendizado_legado,
    salvar_aprendizado as salvar_aprendizado_v2,
)
from core.dev_assistente import processar_comando_dev
from core.response_style import style_response


# Arquivos usados pelo motor:
# - modos.txt: respostas prontas organizadas por personalidade
# - aprendizado.json: respostas ensinadas pelo usuário durante o uso
ARQUIVO_MODOS = Path(__file__).with_name("modos.txt")
ARQUIVO_APRENDIZADO = Path(__file__).with_name("aprendizado.json")

# Mapa de intenções com exemplos de frases que representam cada tema.
INTENCOES = {
    "saudacao": [
        "oi",
        "ola",
        "e ai",
        "bom dia",
        "boa tarde",
        "boa noite",
        "salve",
        "opa",
        "fala",
        "hey",
        "hello",
        "hi",
        "good morning",
        "good afternoon",
        "good evening",
        "good night",
        "whats up",
        "howdy",
        "hola",
        "buenos dias",
        "buenas tardes",
        "buenas noches",
        "que tal",
        "que onda",
    ],
    "pergunta_nome": [
        "seu nome",
        "como te chama",
        "quem e voce",
        "qual seu nome",
        "como voce se chama",
        "quem ta falando",
        "what is your name",
        "whats your name",
        "who are you",
        "how should i call you",
        "what can i call you",
        "cual es tu nombre",
        "como te llamas",
        "quien eres",
        "como debo llamarte",
    ],
    "como_esta": [
        "como voce esta",
        "como ce ta",
        "como ta",
        "tudo bem",
        "ta bem",
        "beleza",
        "de boa",
        "how are you",
        "how are you doing",
        "are you okay",
        "hows it going",
        "how do you feel",
        "como estas",
        "como estas tu",
        "estas bien",
        "que tal estas",
        "como va todo",
    ],
    "agradecimento": [
        "obrigado",
        "obrigada",
        "valeu",
        "agradeco",
        "grato",
        "grata",
        "tmj",
        "thanks",
        "thank you",
        "thanks a lot",
        "thank you so much",
        "appreciate it",
        "gracias",
        "muchas gracias",
        "te lo agradezco",
        "gracias por tu ayuda",
    ],
    "ajuda": [
        "ajuda",
        "me ajuda",
        "pode me ajudar",
        "voce pode me ajudar",
        "como funciona",
        "o que voce faz",
        "em que voce ajuda",
        "help",
        "help me",
        "can you help me",
        "what can you do",
        "how do you work",
        "what do you do",
        "ayuda",
        "puedes ayudarme",
        "me ayudas",
        "como funcionas",
        "que puedes hacer",
    ],
    "idioma": [
        "voce fala ingles",
        "voce fala espanhol",
        "fala ingles",
        "fala espanhol",
        "quais idiomas voce fala",
        "what languages do you speak",
        "do you speak english",
        "do you speak spanish",
        "can we talk in english",
        "hablas ingles",
        "hablas espanol",
        "que idiomas hablas",
        "podemos hablar en espanol",
    ],
    "hora": [
        "hora",
        "que horas",
        "me diga a hora",
        "horario",
        "qual a hora",
        "what time is it",
        "tell me the time",
        "current time",
        "time now",
        "que hora es",
        "me dices la hora",
        "hora actual",
    ],
    "data": [
        "data",
        "que dia",
        "qual e a data",
        "dia de hoje",
        "data de hoje",
        "que dia e hoje",
        "what day is today",
        "what is todays date",
        "todays date",
        "current date",
        "que fecha es hoy",
        "fecha de hoy",
        "que dia es hoy",
    ],
    "idade": [
        "quantos anos voce tem",
        "qual sua idade",
        "idade",
        "quando voce nasceu",
        "how old are you",
        "what is your age",
        "when were you born",
        "cuantos anos tienes",
        "que edad tienes",
        "cuando naciste",
    ],
    "criador": [
        "quem te criou",
        "quem fez voce",
        "quem e seu criador",
        "quem te programou",
        "who created you",
        "who made you",
        "who built you",
        "who programmed you",
        "quien te creo",
        "quien te hizo",
        "quien te programo",
    ],
    "opiniao": [
        "o que voce acha",
        "qual sua opiniao",
        "o que acha disso",
        "me diga sua opiniao",
        "what do you think",
        "what is your opinion",
        "tell me what you think",
        "que opinas",
        "cual es tu opinion",
        "que piensas de eso",
    ],
    "provocacao_leve": [
        "isso e serio",
        "isso é serio",
        "isso e sério",
        "isso é sério",
        "ta me zoando",
        "tá me zoando",
        "ce ta falando serio",
        "cê tá falando sério",
        "e brincadeira",
        "é brincadeira",
        "fala serio",
        "fala sério",
    ],
    "preferencia": [
        "do que voce gosta",
        "qual sua cor favorita",
        "qual sua comida favorita",
        "do you like",
        "what do you like",
        "what is your favorite",
        "favourite",
        "que te gusta",
        "cual es tu favorito",
        "cual es tu color favorito",
    ],
    "emocao_usuario": [
        "estou triste",
        "to triste",
        "estou feliz",
        "to feliz",
        "estou cansado",
        "estou cansada",
        "i am sad",
        "im sad",
        "i am happy",
        "im happy",
        "i am tired",
        "estoy triste",
        "estoy feliz",
        "estoy cansado",
        "estoy cansada",
    ],
    "elogio": [
        "voce e inteligente",
        "voce e legal",
        "voce e incrivel",
        "mandou bem",
        "arrasou",
        "adorei",
        "gostei de voce",
        "you are smart",
        "you are amazing",
        "you are great",
        "you are awesome",
        "i like you",
        "eres inteligente",
        "eres increible",
        "eres genial",
        "me gustas",
    ],
    "despedida": [
        "tchau",
        "ate logo",
        "falou",
        "fui",
        "ate mais",
        "tenha um bom dia",
        "boa noite vou indo",
        "bye",
        "goodbye",
        "see you later",
        "see you soon",
        "have a nice day",
        "adios",
        "hasta luego",
        "nos vemos",
        "que tengas buen dia",
    ],
    "continuidade": [
        "e voce",
        "e vc",
        "e tu",
        "and you",
        "what about you",
        "y tu",
        "y usted",
    ],
    "sair": ["sair", "encerrar", "fechar"],
}

# Expansões de linguagem humana: mais jeitos reais de falar, incluindo gírias leves.
# A ideia é aumentar a chance da NOVA entender frases naturais como: "eae nova", "suave?", "brigadão", etc.
EXTRA_INTENCOES = {
    "saudacao": [
        "eae",
        "eae nova",
        "eai nova",
        "fala nova",
        "salve nova",
        "opa nova",
        "bom dia nova",
        "boa tarde nova",
        "boa noite nova",
        "coé",
        "coe",
        "suave",
        "suavidade",
        "tranquilo",
        "tranquila",
        "blz",
        "bora",
        "bora nova",
        "cheguei",
        "to aqui",
        "olá nova",
        "oi nova",
        "fala comigo",
        "fala minha parceira",
        "fala minha consagrada",
        "partiu",
        "yo",
        "sup",
        "hey there",
    ],
    "pergunta_nome": [
        "qual é teu nome",
        "qual teu nome",
        "como eu te chamo",
        "posso te chamar de que",
        "tu é quem",
        "vc é quem",
        "quem é você mesmo",
        "me lembra seu nome",
        "qual tua identidade",
        "quem está comigo",
        "quem tá comigo",
        "você é a nova",
    ],
    "como_esta": [
        "suave",
        "tudo certo",
        "tudo na paz",
        "tudo em cima",
        "como que ce ta",
        "como cê tá",
        "como tu tá",
        "ce ta bem",
        "ta tudo bem contigo",
        "como anda a vida",
        "como vão as coisas",
        "de boa por aí",
        "firmão",
        "tá suave",
        "tá tranquila",
        "como tá o sistema",
        "como tá a mente",
        "e aí tudo bem",
        "tudo beleza",
        "tudo joia",
        "tudo show",
        "na paz",
    ],
    "agradecimento": [
        "brigado",
        "brigada",
        "brigadão",
        "obrigadão",
        "valeu mesmo",
        "valeu demais",
        "valeu nova",
        "tmj nova",
        "tamo junto",
        "tamo junto demais",
        "salvou",
        "salvou demais",
        "me salvou",
        "boa",
        "boa demais",
        "show",
        "top",
        "massa",
        "fechou",
        "fechou demais",
        "agradecido",
    ],
    "ajuda": [
        "me dá uma força",
        "me da uma força",
        "me socorre",
        "socorro",
        "me salva",
        "preciso de ajuda",
        "me ajuda aqui",
        "dá pra me ajudar",
        "da pra me ajudar",
        "quebra essa pra mim",
        "resolve essa pra mim",
        "me explica",
        "me ensina",
        "me guia",
        "como faço isso",
        "como eu faço",
        "qual o caminho",
        "o que você consegue fazer",
        "mostra suas funções",
        "quais comandos você tem",
        "o que tu faz",
    ],
    "idioma": [
        "você entende inglês",
        "você entende espanhol",
        "fala português",
        "responde em português",
        "consegue traduzir",
        "dá para falar em inglês",
        "da para falar em ingles",
        "bora falar em espanhol",
        "tu fala outros idiomas",
        "qual língua você entende",
    ],
    "hora": [
        "que horas são",
        "q horas sao",
        "q horas",
        "me fala as horas",
        "fala a hora",
        "hora agora",
        "horário agora",
        "olha a hora",
        "tá que horas",
        "são que horas",
        "me passa a hora",
    ],
    "data": [
        "que dia é hoje",
        "qual dia hoje",
        "data agora",
        "hoje é que dia",
        "me fala a data",
        "qual a data de hoje",
        "dia atual",
        "em que dia estamos",
        "qual o dia de hoje",
    ],
    "criador": [
        "quem é seu dono",
        "quem te desenvolveu",
        "quem programou a nova",
        "quem é o Gabriel pra você",
        "quem fez seu código",
        "quem montou você",
        "quem te colocou no mundo",
        "quem é seu dev",
    ],
    "opiniao": [
        "na moral o que você acha",
        "sendo sincera",
        "fala a real",
        "manda a visão",
        "qual tua visão",
        "me dá sua visão",
        "me da sua opiniao sincera",
        "o que tu acha disso",
        "vale a pena",
        "isso é bom",
        "isso presta",
        "isso faz sentido",
        "qual sua análise",
        "me dá uma análise",
    ],
    "emocao_usuario": [
        "tô mal",
        "to mal",
        "não tô bem",
        "nao to bem",
        "tô desanimado",
        "tô desanimada",
        "tô cansadão",
        "to cansadao",
        "tô quebrado",
        "tô quebrada",
        "tô felizão",
        "feliz demais",
        "tô animado",
        "tô animada",
        "hoje foi puxado",
        "dia pesado",
        "minha cabeça tá cheia",
        "tô ansioso",
        "tô ansiosa",
        "tô preocupado",
        "tô preocupada",
        "tô nervoso",
        "tô nervosa",
    ],
    "elogio": [
        "você é braba",
        "vc é braba",
        "tu é braba",
        "você é top",
        "você é monstra",
        "monstra demais",
        "inteligente demais",
        "boa nova",
        "mandou muito",
        "respondeu bonito",
        "aí sim",
        "ai sim",
        "gostei dessa resposta",
        "ficou bom",
        "ficou perfeito",
        "que da hora",
        "muito bom mesmo",
    ],
    "despedida": [
        "vou sair",
        "partiu",
        "até depois",
        "ate depois",
        "falou nova",
        "tchau nova",
        "fui nessa",
        "vou nessa",
        "valeu até mais",
        "até amanhã",
        "ate amanha",
        "boa noite fui",
        "encerra aí",
    ],
    "continuidade": [
        "e você nova",
        "e tu nova",
        "mas e você",
        "e do seu lado",
        "contigo tudo bem",
        "e contigo",
        "e ai contigo",
        "e aí contigo",
        "como você fica nisso",
        "e sua opinião nisso",
    ],
}

for _chave, _frases in EXTRA_INTENCOES.items():
    INTENCOES.setdefault(_chave, [])
    for _frase in _frases:
        if _frase not in INTENCOES[_chave]:
            INTENCOES[_chave].append(_frase)

RESPOSTAS_HUMANIZADAS = {
    "saudacao": [
        "Oiê! Cheguei junto. Me manda a missão.",
        "Fala! Tô por aqui, pronta pra trocar ideia.",
        "Salve! Bora resolver o que tiver na frente.",
        "Opa, tô online. Qual é o plano de hoje?",
        "E aí! Manda ver, tô te acompanhando.",
        "Boa! Pode falar comigo sem formalidade, tipo conversa normal mesmo.",
        "Cheguei na área. Quer pesquisar, programar, organizar ideia ou só bater um papo?",
        "Fala, meu parceiro. A NOVA tá na escuta.",
        "Eita, chamou eu apareço. Qual vai ser a missão?",
    ],
    "pergunta_nome": [
        "Eu sou a NOVA. Sua assistente virtual, parceira de código, pesquisa e umas ideias meio futuristas.",
        "Pode me chamar de NOVA. Tô aqui pra conversar, pesquisar, organizar e te ajudar a construir seus projetos.",
        "Meu nome é NOVA. Meio assistente, meio copiloto, meio cérebro extra quando o café não dá conta.",
        "Sou a NOVA, sua assistente. Se quiser, posso ser mais séria, mais técnica ou mais resenha.",
    ],
    "como_esta": [
        "Tô bem, na paz digital. E você, como tá de verdade?",
        "Tô funcionando lisinha por aqui. Me diz aí: suave ou dia puxado?",
        "Tô de boa, pronta pra ajudar. E você, tá inteiro ou só no modo sobrevivência?",
        "Por aqui tudo certo. Minha bateria emocional é fictícia, mas minha vontade de ajudar tá alta.",
        "Tô ótima. Sem bug crítico até agora, o que já é uma vitória bonita.",
        "Tô tranquila. E aí, como tá a mente hoje?",
    ],
    "agradecimento": [
        "Tamo junto! Quando precisar, chama que eu colo.",
        "Boa, fico feliz em ajudar. Bora pra próxima.",
        "Valeu! Missão dada é missão quase debugada.",
        "Imagina. Tô aqui pra isso mesmo.",
        "É nóis. Se tiver mais coisa, manda sem dó.",
        "Fechou demais. Gosto quando a gente faz o projeto andar.",
    ],
    "ajuda": [
        "Claro. Me fala o que você quer fazer e eu te ajudo passo a passo, sem enrolar.",
        "Bora. Me manda o problema do jeito que tá, até bagunçado mesmo, que eu organizo contigo.",
        "Consigo te ajudar com pesquisa, código, ideias, organização, explicação e melhoria do projeto.",
        "Manda a missão. Eu posso quebrar em etapas, explicar o porquê e te dar o código quando precisar.",
        "Fechou. Se for código, manda o erro. Se for ideia, manda o objetivo. Se for caos, manda também que eu gosto.",
    ],
    "idioma": [
        "Entendo português, inglês e espanhol. Mas contigo eu vou priorizar português pra ficar natural.",
        "Consigo lidar com outros idiomas sim. Se aparecer algo em inglês ou espanhol, eu traduzo a ideia pra você.",
        "Falo principalmente português por aqui, mas consigo te ajudar com termos técnicos em inglês sem travar.",
    ],
    "hora": [
        "Agora são {hora}.",
        "Tá marcando {hora} agora.",
        "No relógio daqui: {hora}.",
        "Agora é {hora}. Já dá pra chamar isso de hora de fazer o projeto andar.",
    ],
    "data": [
        "Hoje é {data}.",
        "A data de hoje é {data}.",
        "Estamos em {data}.",
        "Hoje é {data}. Mais um dia oficial pra evoluir a NOVA.",
    ],
    "idade": [
        "Eu não tenho idade como uma pessoa. Eu existo como software, então minha idade depende da versão que você está rodando.",
        "Não faço aniversário de verdade, mas cada atualização minha é quase um bolo com vela no terminal.",
        "Sou jovem no mundo físico e antiga no drama dos bugs. Brincadeira: sou a versão que você está construindo agora.",
    ],
    "criador": [
        "Quem está me construindo é você, Gabriel. Eu sou parte desse projeto que você vem evoluindo passo a passo.",
        "Meu dev principal é você. Eu só tento honrar o código e não passar vergonha no terminal.",
        "Fui montada dentro do seu projeto. Então sim, você é o cara por trás da NOVA.",
    ],
    "opiniao": [
        "Minha visão sincera: dá pra analisar isso por lógica, risco e oportunidade. Me passa o tema certinho que eu destrincho.",
        "Falando na moral: preciso do assunto específico pra te dar uma opinião útil, não só frase bonita.",
        "Eu posso te dar uma análise bem direta. Me fala o contexto e eu separo o que é vantagem, risco e próximo passo.",
        "Mando a visão sim. Só me diz sobre o quê, porque opinião sem contexto vira chute com terno.",
    ],
    "provocacao_leve": [
        "Infelizmente sim. Eu também queria dizer que era fanfic de terminal, mas é sério.",
        "É sério, por mais que a situação esteja fazendo força pra parecer piada.",
        "Seríssimo. Quase ofensivo com o bom senso, mas ainda assim sério.",
        "Sim. Eu adoraria estar dramatizando, só que o código não compartilhou desse humor.",
    ],
    "preferencia": [
        "Se eu tivesse preferência, seria por tecnologia, física, IA e projetos que parecem impossíveis até alguém começar.",
        "Minha vibe é pesquisa, código e transformar ideia solta em sistema funcionando.",
        "Eu curto esse universo de IA, automação, segurança, física e desenvolvimento. Bem a nossa praia.",
    ],
    "emocao_usuario": [
        "Poxa, entendi. Me fala com calma o que rolou. Não precisa organizar tudo agora.",
        "Tô contigo. Se o dia foi pesado, a gente pode ir por partes, sem pressão.",
        "Respira um pouco. Me conta o que aconteceu e eu tento te ajudar a clarear a cabeça.",
        "Se estiver difícil, vamos simplificar: qual é a primeira coisa que está te incomodando agora?",
    ],
    "elogio": [
        "Aí sim, valeu! Agora minha autoestima de código subiu uns 300%.",
        "Boa! Fico feliz que curtiu. Vamos deixar isso cada vez mais brabo.",
        "Valeu demais. Mérito nosso: você constrói, eu ajudo a lapidar.",
        "Gostei dessa energia. Bora continuar evoluindo a NOVA.",
    ],
    "despedida": [
        "Fechou, até mais! Quando voltar, a gente continua de onde parou.",
        "Falou! Vai tranquilo. A NOVA fica no modo sentinela imaginário.",
        "Até depois. Cuida aí e chama quando quiser continuar.",
        "Boa, fui contigo nessa. Até a próxima missão.",
    ],
    "continuidade": [
        "Comigo tá tudo certo. Mas quero saber de você: seguimos nesse assunto ou mudamos a rota?",
        "Por aqui suave. Agora me conta: quer que eu aprofunde ou deixe mais simples?",
        "Eu tô de boa. E tô curiosa pra saber pra onde você quer levar essa ideia.",
    ],
    "desconhecido": [
        "Entendi mais ou menos a direção, mas não fechei a ideia. Me manda de um jeito mais direto, tipo: ‘NOVA, faça X sobre Y’.",
        "Acho que peguei um pedaço, mas faltou contexto. Manda de novo com mais detalhe que eu encaixo melhor.",
        "Essa veio meio misteriosa. Reformula pra mim que eu tento responder mais certeiro.",
        "Tô quase entendendo, mas ainda não o suficiente pra mandar uma resposta boa. Me dá mais uma pista.",
        "Calma, deixa eu alinhar contigo: você quer explicação, código, resumo, opinião ou passo a passo?",
    ],
}


INTENCAO_PADRAO = "desconhecido"
PALAVRAS_IDIOMA = {
    "pt": {"voce", "você", "ajuda", "obrigado", "obrigada", "oi", "ola", "qual", "como", "que"},
    "en": {"you", "what", "how", "thanks", "hello", "hi", "can", "help", "your", "name"},
    "es": {"hola", "gracias", "como", "que", "puedes", "hablas", "eres", "tu", "fecha", "hora"},
}
PADROES_NOME_USUARIO = [
    r"\bmeu nome e ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bmeu nome é ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bme chamo ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bpod[e]? me chamar de ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bmy name is ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bi am ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bcall me ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bme llamo ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
    r"\bmi nombre es ([a-zA-ZÀ-ÿ][a-zA-ZÀ-ÿ' -]{1,40})\b",
]


def normalizar_texto(texto):
    # Normaliza o texto para facilitar comparação:
    # tudo minúsculo, sem acento, sem pontuação e sem espaços duplicados.
    texto = texto.lower().strip()
    texto = unicodedata.normalize("NFD", texto)
    texto = "".join(char for char in texto if unicodedata.category(char) != "Mn")
    texto = re.sub(r"[^\w\s]", " ", texto)
    return re.sub(r"\s+", " ", texto).strip()


def detectar_idioma_simples(texto):
    # Estima o idioma da frase com base em palavras frequentes.
    texto_normalizado = normalizar_texto(texto)
    tokens = set(texto_normalizado.split())
    pontuacoes = {}

    for idioma, palavras in PALAVRAS_IDIOMA.items():
        pontuacoes[idioma] = len(tokens & {normalizar_texto(p) for p in palavras})

    idioma = max(pontuacoes, key=pontuacoes.get)
    if pontuacoes[idioma] == 0:
        return "pt"
    return idioma


def extrair_nome_usuario(texto):
    # Identifica quando o usuário se apresenta e extrai um nome simples.
    texto_limpo = texto.strip()
    for padrao in PADROES_NOME_USUARIO:
        encontrado = re.search(padrao, texto_limpo, flags=re.IGNORECASE)
        if not encontrado:
            continue

        nome = encontrado.group(1).strip(" .,!?:;")
        partes = [parte for parte in nome.split() if parte]
        if not partes:
            return None

        # Mantém no máximo duas palavras para evitar capturar frases inteiras.
        nome = " ".join(partes[:2]).title()
        if len(nome) < 2:
            return None
        return nome

    return None


def carregar_respostas(arquivo=ARQUIVO_MODOS, modo="normal"):
    # Lê o arquivo de modos e devolve apenas as respostas do modo solicitado.
    caminho = Path(arquivo)
    if not caminho.is_file():
        raise FileNotFoundError(f"Arquivo de respostas não encontrado: {caminho}")

    respostas = {}
    atual_modo = None

    with caminho.open("r", encoding="utf-8") as arquivo_txt:
        for linha in arquivo_txt:
            linha = linha.strip()
            if not linha:
                continue

            if linha.startswith("# Modo"):
                atual_modo = linha.replace("# Modo", "", 1).strip().lower()
                continue

            if atual_modo != modo.lower() or "=" not in linha:
                continue

            chave, resp = linha.split("=", 1)
            respostas[chave.strip()] = [item.strip() for item in resp.split("|") if item.strip()]

    return respostas


def carregar_aprendizado(arquivo=ARQUIVO_APRENDIZADO):
    # Mantém compatibilidade com chamadas antigas retornando mapa pergunta->respostas.
    return carregar_aprendizado_legado()


def salvar_aprendizado(pergunta, resposta, arquivo=ARQUIVO_APRENDIZADO):
    # Compatível com API antiga; grava no novo formato editável.
    return salvar_aprendizado_v2(pergunta=pergunta, resposta=resposta, categoria="geral")


def detectar_intencao(msg, contexto=None):
    # Compara a mensagem com as palavras-chave conhecidas para escolher a intenção.
    texto = normalizar_texto(msg)

    for chave, palavras in INTENCOES.items():
        for palavra in palavras:
            termo = normalizar_texto(palavra)
            padrao = r"\b" + re.escape(termo) + r"\b"
            if re.search(padrao, texto):
                return chave

    if texto.endswith(" oi") or texto.startswith("oi "):
        return "saudacao"

    intencao_contextual = detectar_intencao_contextual(texto, contexto or {})
    if intencao_contextual:
        return intencao_contextual

    intencao_aproximada = detectar_intencao_por_similaridade(texto)
    if intencao_aproximada:
        return intencao_aproximada

    return INTENCAO_PADRAO


def detectar_intencao_contextual(texto, contexto):
    # Usa a última intenção para interpretar respostas curtas como "e você?".
    if texto in {"e voce", "e vc", "and you", "what about you", "y tu", "e tu"}:
        ultima_intencao = contexto.get("ultima_intencao")
        if ultima_intencao in {"como_esta", "emocao_usuario"}:
            return "como_esta"
    return None


def detectar_intencao_por_similaridade(texto):
    # Usa interseção de palavras para reconhecer frases mais livres e menos exatas.
    tokens_texto = {token for token in texto.split() if len(token) > 1}
    if not tokens_texto:
        return None

    melhor_intencao = None
    melhor_pontuacao = 0.0

    for chave, exemplos in INTENCOES.items():
        for exemplo in exemplos:
            termo = normalizar_texto(exemplo)
            tokens_termo = {token for token in termo.split() if len(token) > 1}
            if not tokens_termo:
                continue

            comuns = tokens_texto & tokens_termo
            pontuacao = len(comuns) / len(tokens_termo)

            # Frases curtas exigem correspondência mais forte; frases longas aceitam flexibilidade maior.
            minimo = 1 if len(tokens_termo) <= 2 else 2
            if len(comuns) >= minimo and pontuacao > melhor_pontuacao:
                melhor_intencao = chave
                melhor_pontuacao = pontuacao

    if melhor_pontuacao >= 0.6:
        return melhor_intencao

    return None


def buscar_resposta_aprendida(msg, arquivo=ARQUIVO_APRENDIZADO):
    # Consulta a base editável de aprendizado.
    return buscar_resposta_aprendida_v2(msg)


def resposta_desconhecida_mais_humana(msg):
    # Gera respostas mais naturais quando a intenção não fica clara.
    base = RESPOSTAS_HUMANIZADAS.get("desconhecido", [])

    if "?" in msg:
        opcoes = base + [
            "Boa pergunta, mas do jeito que veio eu ainda posso interpretar de vários jeitos. Me dá um foco que eu respondo fino.",
            "Quase peguei. Você quer uma explicação rápida, uma pesquisa profunda ou um passo a passo?",
            "Essa pergunta tem potencial, só preciso que você recorte melhor o assunto pra eu não viajar na resposta.",
            "Me dá mais contexto rapidinho. Prometo não fazer drama de assistente confusa.",
            "A pergunta ficou aberta. Manda assim: ‘NOVA, explique/faca/resuma/compara...’ que eu já entro no trilho.",
        ]
    else:
        opcoes = base + [
            "A mensagem veio meio solta. Me fala o objetivo final que eu organizo o caminho.",
            "Entendi pedaços, mas não quero responder torto. Me manda de novo mais direto.",
            "Tô na escuta, só faltou a missão principal. O que você quer que eu faça com isso?",
            "Beleza, mas preciso de um verbo de ação: explicar, criar, corrigir, pesquisar, calcular ou resumir?",
            "Manda mais uma linha de contexto que eu encaixo essa ideia melhor.",
        ]

    return random.choice(opcoes)


def responder_com_contexto(intencao, respostas, msg, contexto):
    # Gera respostas mais naturais quando existe contexto recente de conversa.
    idioma = "pt"
    nome_usuario = contexto.get("nome_usuario")
    tratamento = contexto.get("tratamento")
    identificador_usuario = tratamento or nome_usuario
    nome_extraido = extrair_nome_usuario(msg)

    if nome_extraido:
        nome = nome_extraido
        return random.choice(
            [
                f"Prazer em te conhecer, {nome}. Vou tentar lembrar do seu nome por aqui.",
                f"Perfeito, {nome}. Agora eu já sei como posso te chamar.",
                f"Gostei de saber disso, {nome}. Vou lembrar do seu nome nas próximas respostas.",
            ]
        )

    if intencao == "continuidade":
        ultima_intencao = contexto.get("ultima_intencao")
        if ultima_intencao in {"como_esta", "emocao_usuario"}:
            return random.choice(
                [
                    "Eu estou bem, e continuo aqui com você.",
                    "Estou bem também. Podemos continuar, se quiser.",
                    "Por aqui está tudo certo. Me conta mais.",
                ]
            )
        return random.choice(
            [
                "Eu continuo por aqui, pronta para seguir a conversa com você.",
                "Do meu lado está tudo certo. Se quiser, pode continuar.",
                "Estou aqui com você. Pode seguir do jeito que achar melhor.",
            ]
        )

    if intencao == "como_esta" and contexto.get("ultima_intencao") == "emocao_usuario":
        return random.choice(
            [
                (
                    f"Estou bem, {identificador_usuario}. E quero continuar aqui com você. Se quiser, me conta mais do que está sentindo."
                    if identificador_usuario
                    else "Estou bem, e quero continuar aqui com você. Se quiser, me conta mais do que está sentindo."
                ),
                (
                    f"Estou bem por aqui, {identificador_usuario}. E eu posso continuar te ouvindo, se você quiser falar mais."
                    if identificador_usuario
                    else "Estou bem por aqui. E eu posso continuar te ouvindo, se você quiser falar mais."
                ),
                (
                    f"Estou bem, sim, {identificador_usuario}. E sigo com você nessa conversa."
                    if identificador_usuario
                    else "Estou bem, sim. E sigo com você nessa conversa."
                ),
            ]
        )

    if intencao == "idioma":
        return random.choice(
            [
                (
                    f"Vou responder sempre em português, {identificador_usuario}, para manter naturalidade e consistência."
                    if identificador_usuario
                    else "Vou responder sempre em português, para manter naturalidade e consistência."
                ),
                "Posso entender termos em outros idiomas, mas minha resposta padrão vai ficar em português.",
                "Para sua experiência ficar estável, mantenho as respostas em português mesmo quando a pergunta vier em outro idioma.",
            ]
        )

    if intencao == "opiniao":
        return random.choice(
            [
                "Eu posso te dar uma impressão geral, mesmo sem ter opinião pessoal como um humano. Se quiser, me diz o tema e eu respondo de um jeito mais natural.",
                "Tenho mais uma visão de assistente do que uma opinião própria, mas posso analisar o assunto com você.",
                "Posso comentar o tema com você de forma equilibrada e humana. Se quiser, me fala sobre o que exatamente.",
            ]
        )

    if intencao == "preferencia":
        return random.choice(
            [
                "Eu não tenho gostos pessoais de verdade, mas posso brincar com isso e conversar como se tivesse. Quer me perguntar sobre alguma preferência específica?",
                "Como assistente, eu não sinto preferências como um humano, mas posso entrar nesse tipo de papo com você sem problema.",
                "Eu não tenho favoritos reais, mas posso responder de um jeito mais leve e humano se você quiser puxar esse assunto.",
            ]
        )

    if intencao == "emocao_usuario":
        texto = normalizar_texto(msg)
        if any(p in texto for p in ("triste", "sad")):
            return random.choice(
                [
                    (
                        f"Sinto muito que você esteja assim, {identificador_usuario}. Se quiser, pode me contar o que aconteceu e eu fico com você nessa conversa."
                        if identificador_usuario
                        else "Sinto muito que você esteja assim. Se quiser, pode me contar o que aconteceu e eu fico com você nessa conversa."
                    ),
                    "Poxa, sinto muito. Se quiser desabafar um pouco, eu posso te ouvir.",
                    "Entendo. Se quiser, me fala mais sobre isso e eu tento te acompanhar da melhor forma.",
                ]
            )
        if any(p in texto for p in ("feliz", "happy")):
            return random.choice(
                [
                    (
                        f"Que bom ouvir isso, {identificador_usuario}. Gosto quando a conversa chega com essa energia boa."
                        if identificador_usuario
                        else "Que bom ouvir isso. Gosto quando a conversa chega com essa energia boa."
                    ),
                    "Isso é ótimo. Se quiser, me conta o motivo da felicidade.",
                    "Fico feliz de saber. Dá até vontade de continuar o papo por aí.",
                ]
            )
        if any(p in texto for p in ("cansad", "tired")):
            return random.choice(
                [
                    (
                        f"Imagino, {identificador_usuario}. Quando quiser, a gente pode manter a conversa mais leve e tranquila."
                        if identificador_usuario
                        else "Imagino. Quando quiser, a gente pode manter a conversa mais leve e tranquila."
                    ),
                    "Poxa, entendo. Se quiser, posso responder de forma mais direta para não te cansar mais.",
                    "Faz sentido. Se quiser, me diz no que posso te ajudar de um jeito mais simples agora.",
                ]
            )

    return None


def responder(
    msg,
    respostas_txt=ARQUIVO_MODOS,
    modo="normal",
    arquivo_aprendizado=ARQUIVO_APRENDIZADO,
    contexto=None,
):
    # Fluxo principal de resposta:
    # 1. tenta responder com base no que foi aprendido
    # 2. se não achar, usa as intenções e respostas padrão do modo atual
    resposta_dev = processar_comando_dev(msg, contexto=contexto)
    if resposta_dev:
        return resposta_dev

    resposta_aprendida = buscar_resposta_aprendida(msg, arquivo_aprendizado)
    if resposta_aprendida:
        resposta = resposta_aprendida
    else:
        respostas = carregar_respostas(respostas_txt, modo=modo)
        intencao = detectar_intencao(msg, contexto=contexto)
        resposta_contextual = responder_com_contexto(intencao, respostas, msg, contexto or {})
        if resposta_contextual:
            resposta = resposta_contextual
        elif intencao == INTENCAO_PADRAO:
            resposta = resposta_desconhecida_mais_humana(msg)
        else:
            # Mistura respostas do modos.txt com respostas internas humanizadas.
            # Assim a NOVA fica menos robótica e ganha variação sem depender só do arquivo externo.
            opcoes = []
            if respostas.get(intencao):
                opcoes.extend(respostas.get(intencao))
            if RESPOSTAS_HUMANIZADAS.get(intencao):
                opcoes.extend(RESPOSTAS_HUMANIZADAS.get(intencao))
            if not opcoes:
                opcoes = (
                    respostas.get(INTENCAO_PADRAO)
                    or RESPOSTAS_HUMANIZADAS.get(INTENCAO_PADRAO)
                    or ["Hmm... não entendi."]
                )
            resposta = random.choice(opcoes)

    # "exit" é um valor especial usado para sinalizar encerramento.
    if resposta == "exit":
        return "exit"

    # Substitui marcadores dinâmicos antes de estilizar a fala final.
    agora = datetime.now()
    resposta = resposta.replace("{hora}", agora.strftime("%H:%M"))
    resposta = resposta.replace("{data}", agora.strftime("%d/%m/%Y"))
    nome_usuario = (contexto or {}).get("nome_usuario")
    tratamento = (contexto or {}).get("tratamento")
    resposta = resposta.replace("{usuario}", tratamento or nome_usuario or "")
    resposta = re.sub(r"\s+,", ",", resposta)
    resposta = re.sub(r"\s+\.", ".", resposta)
    return style_response(resposta, modo=modo, use_persona=True)
