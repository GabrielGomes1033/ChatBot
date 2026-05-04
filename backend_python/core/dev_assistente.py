from __future__ import annotations

from pathlib import Path
import re
import unicodedata

from core.dev_gerador import (
    criar_estrutura,
    formatar_lista_arquivos,
    nome_seguro,
    pasta_projetos_gerados,
)
from core.dev_revisor import analisar_erro, explicar_codigo
from core.dev_templates import (
    ADMIN_CSS,
    ADMIN_HTML,
    ADMIN_JS,
    API_FLASK_SQLITE,
    API_FASTAPI,
    API_FLASK,
    CSS_BASICO,
    ESTOQUE_CSS,
    ESTOQUE_HTML,
    ESTOQUE_JS,
    HTML_BASICO,
    JS_BASICO,
    LOGIN_CSS,
    LOGIN_HTML,
    LOGIN_JS,
    README_ADMIN,
    README_API,
    README_API_DB,
    README_ESTOQUE,
    README_SITE,
    REQUIREMENTS_FLASK_SQLITE,
    REQUIREMENTS_FASTAPI,
    REQUIREMENTS_FLASK,
)


_LANGUAGE_LABELS = {
    "html_css_js": "HTML, CSS e JavaScript",
    "javascript": "JavaScript",
    "python": "Python",
    "java": "Java",
    "cpp": "C++",
}

_GENERIC_DEV_HINTS = (
    "codigo",
    "html",
    "css",
    "javascript",
    "python",
    "java",
    "c++",
    "cpp",
    "site",
    "tela",
    "pagina",
    "interface",
    "login",
    "dashboard",
    "painel",
    "api",
    "sistema",
    "app",
    "aplicativo",
    "script",
    "backend",
)


def _normalizar(texto: str) -> str:
    base = unicodedata.normalize("NFKD", str(texto or ""))
    base = base.encode("ascii", "ignore").decode("ascii").lower()
    return re.sub(r"\s+", " ", base).strip()


def _limpar_prefixo_nova(texto: str) -> str:
    return re.sub(r"^(nova[,:\s-]+)", "", str(texto or "").strip(), flags=re.IGNORECASE).strip()


_VERBOS_CRIACAO = r"(?:criar|cria|crie|gerar|gera|gere|montar|monte|fazer|faz|faca|faça|desenvolver|desenvolva|quero|preciso(?:\s+de)?)"


def _extrair_nome_projeto(comando: str, padrao: str, default: str) -> str:
    texto = _limpar_prefixo_nova(comando)
    match = re.search(
        padrao + r"(?:\s+(?:chamado|com nome|nomeado)\s+(.+))?$",
        texto,
        flags=re.IGNORECASE,
    )
    if not match:
        return default

    candidato = (match.group(1) or "").strip(" .,:;\"'")
    if not candidato:
        return default

    candidato = re.sub(
        r"\b(para mim|por favor|agora|basico|b[aá]sico)\b",
        "",
        candidato,
        flags=re.IGNORECASE,
    ).strip(" _-")
    return nome_seguro(candidato or default)


def _resumo_criacao(tipo: str, payload: dict[str, object]) -> str:
    nome = str(payload.get("project_name", "projeto"))
    criados = formatar_lista_arquivos(payload.get("created_files", []))
    preservados = formatar_lista_arquivos(payload.get("preserved_files", []))
    caminho = payload.get("project_dir")
    pasta = nome if not isinstance(caminho, Path) else caminho.name

    linhas = [f"{tipo} criado com sucesso na pasta: projetos_gerados/{pasta}"]
    if criados != "nenhum":
        linhas.append(f"Arquivos criados: {criados}")
    if preservados != "nenhum":
        linhas.append(f"Arquivos preservados: {preservados}")
    return "\n".join(linhas)


def _normalizar_linguagem(language: str) -> str:
    normalized = _normalizar(language)
    if not normalized or normalized in {"auto", "automatico", "automatica"}:
        return ""
    if normalized in {"html", "css", "web", "frontend", "html css js"}:
        return "html_css_js"
    if normalized in {"js", "javascript", "node", "nodejs"}:
        return "javascript"
    if normalized in {"python", "py", "fastapi", "flask"}:
        return "python"
    if normalized == "java":
        return "java"
    if normalized in {"c++", "cpp", "cxx"}:
        return "cpp"
    return ""


def _inferir_linguagem(prompt: str, preferred: str = "") -> str:
    language = _normalizar_linguagem(preferred)
    if language:
        return language

    normalized = _normalizar(prompt)
    if "c++" in prompt.lower() or " cpp" in f" {normalized} ":
        return "cpp"
    if "java" in normalized and "javascript" not in normalized:
        return "java"
    if any(token in normalized for token in ("python", "fastapi", "flask", "backend", "api")):
        return "python"
    if (
        any(token in normalized for token in ("javascript", "node", "script js"))
        and not any(
            token in normalized
            for token in ("html", "css", "tela", "pagina", "interface", "login", "dashboard", "painel")
        )
    ):
        return "javascript"
    if any(
        token in normalized
        for token in (
            "html",
            "css",
            "site",
            "tela",
            "pagina",
            "interface",
            "login",
            "dashboard",
            "painel",
            "landing",
        )
    ):
        return "html_css_js"
    if any(token in normalized for token in ("automacao", "terminal", "cli", "script")):
        return "python"
    return "html_css_js"


def _inferir_tipo_projeto(prompt: str, language: str) -> str:
    normalized = _normalizar(prompt)
    if "login" in normalized:
        return "login"
    if "estoque" in normalized:
        return "estoque"
    if any(token in normalized for token in ("dashboard", "painel", "admin")):
        return "dashboard"
    if language == "python" and any(
        token in normalized for token in ("api", "backend", "endpoint", "fastapi", "flask")
    ):
        return "python_api"
    return "generic"


def _titulo_ideia(prompt: str, kind: str) -> str:
    normalized = _normalizar(prompt)
    if kind == "login":
        return "Tela de Login Moderna"
    if kind == "dashboard":
        return "Painel Administrativo"
    if kind == "estoque":
        return "Sistema de Estoque"
    if kind == "python_api":
        return "API Python"
    if "landing" in normalized:
        return "Landing Page"
    if "site" in normalized:
        return "Site Inicial"
    if "automacao" in normalized:
        return "Automacao Inicial"
    if "script" in normalized:
        return "Script Inicial"
    return "Projeto Gerado pela NOVA"


def _nome_projeto_ideia(prompt: str, language: str, project_name: str = "") -> str:
    explicit = nome_seguro(project_name)
    if project_name.strip():
        return explicit

    kind = _inferir_tipo_projeto(prompt, language)
    defaults = {
        "login": "login_moderno",
        "dashboard": "painel_moderno",
        "estoque": "sistema_estoque",
        "python_api": "api_nova",
        "generic": {
            "html_css_js": "interface_web",
            "javascript": "app_javascript",
            "python": "script_python",
            "java": "app_java",
            "cpp": "app_cpp",
        }.get(language, "projeto_nova"),
    }
    fallback = defaults.get(kind, defaults["generic"])
    return nome_seguro(str(fallback))


def _descricao_curta(prompt: str) -> str:
    raw = _limpar_prefixo_nova(prompt).strip()
    compact = re.sub(r"\s+", " ", raw)
    if len(compact) <= 120:
        return compact
    return compact[:117].rstrip() + "..."


def _safe_js_string(value: str) -> str:
    return str(value).replace("\\", "\\\\").replace('"', '\\"')


def _template_web_generico(title: str, prompt: str) -> dict[str, str]:
    description = _descricao_curta(prompt)
    html = f"""<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title}</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <main class="shell">
    <section class="hero-card">
      <span class="eyebrow">Projeto gerado pela NOVA</span>
      <h1>{title}</h1>
      <p>{description}</p>
      <div class="actions">
        <button type="button" class="primary" onclick="showStatus()">Testar interface</button>
        <button type="button" class="secondary">Próximo passo</button>
      </div>
      <div id="status" class="status">A estrutura inicial ja esta pronta para evoluir.</div>
    </section>
  </main>
  <script src="script.js"></script>
</body>
</html>
"""
    css = """* {
  box-sizing: border-box;
}

body {
  margin: 0;
  min-height: 100vh;
  font-family: Arial, sans-serif;
  color: #f8fafc;
  background:
    radial-gradient(circle at top left, rgba(56, 189, 248, 0.28), transparent 28%),
    linear-gradient(135deg, #0f172a, #1e293b 58%, #111827);
}

.shell {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 32px;
}

.hero-card {
  width: min(100%, 720px);
  padding: 36px;
  border-radius: 28px;
  background: rgba(15, 23, 42, 0.72);
  border: 1px solid rgba(148, 163, 184, 0.24);
  box-shadow: 0 24px 60px rgba(15, 23, 42, 0.36);
  backdrop-filter: blur(14px);
}

.eyebrow {
  display: inline-flex;
  margin-bottom: 14px;
  padding: 8px 12px;
  border-radius: 999px;
  background: rgba(56, 189, 248, 0.16);
  color: #7dd3fc;
  font-size: 12px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

h1 {
  margin: 0 0 14px;
  font-size: clamp(2rem, 4vw, 3.4rem);
  line-height: 1.05;
}

p {
  margin: 0;
  color: #cbd5e1;
  line-height: 1.7;
}

.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
  margin-top: 28px;
}

button {
  border: none;
  border-radius: 14px;
  padding: 14px 20px;
  font-size: 15px;
  font-weight: 700;
  cursor: pointer;
}

.primary {
  background: #38bdf8;
  color: #082f49;
}

.secondary {
  background: rgba(255, 255, 255, 0.08);
  color: #f8fafc;
  border: 1px solid rgba(255, 255, 255, 0.14);
}

.status {
  margin-top: 18px;
  color: #93c5fd;
  font-size: 14px;
}
"""
    script = f"""function showStatus() {{
  const status = document.getElementById("status");
  status.textContent = "Interface pronta. Proximo passo sugerido: conectar a logica real de { _safe_js_string(title.lower()) }.";
}}
"""
    readme = f"""# {title}

Projeto inicial gerado automaticamente pela NOVA com base na ideia:

> {description}

## Como executar

Abra o arquivo `index.html` no navegador.
"""
    return {
        "index.html": html,
        "style.css": css,
        "script.js": script,
        "README.md": readme,
    }


def _template_javascript(prompt: str, title: str) -> dict[str, str]:
    description = _descricao_curta(prompt)
    script = f"""const projectIdea = "{_safe_js_string(description)}";

function bootstrap() {{
  console.log("Projeto iniciado:", projectIdea);
  console.log("Titulo:", "{_safe_js_string(title)}");
}}

function nextStep() {{
  return "Separar funcoes por modulos e adicionar testes basicos.";
}}

bootstrap();
"""
    readme = f"""# {title}

Projeto JavaScript gerado pela NOVA.

## Como executar

```bash
node app.js
```
"""
    return {
        "app.js": script,
        "README.md": readme,
    }


def _template_python(prompt: str, title: str) -> dict[str, str]:
    description = _descricao_curta(prompt)
    script = f"""def build_summary() -> str:
    return "{description}"


def main() -> None:
    print("{title}")
    print(build_summary())
    print("Proximo passo: separar regras de negocio em modulos.")


if __name__ == "__main__":
    main()
"""
    readme = f"""# {title}

Projeto Python gerado pela NOVA.

## Como executar

```bash
python main.py
```
"""
    return {
        "main.py": script,
        "README.md": readme,
    }


def _template_java(prompt: str, title: str) -> dict[str, str]:
    description = _descricao_curta(prompt)
    script = f"""public class Main {{
    public static void main(String[] args) {{
        System.out.println("{title}");
        System.out.println("{description}");
        System.out.println("Proximo passo: extrair classes de dominio e adicionar testes.");
    }}
}}
"""
    readme = f"""# {title}

Projeto Java gerado pela NOVA.

## Como executar

```bash
javac Main.java
java Main
```
"""
    return {
        "Main.java": script,
        "README.md": readme,
    }


def _template_cpp(prompt: str, title: str) -> dict[str, str]:
    description = _descricao_curta(prompt)
    script = f"""#include <iostream>
#include <string>

int main() {{
    std::cout << "{title}" << std::endl;
    std::cout << "{description}" << std::endl;
    std::cout << "Proximo passo: separar headers e configurar CMake." << std::endl;
    return 0;
}}
"""
    readme = f"""# {title}

Projeto C++ gerado pela NOVA.

## Como executar

```bash
g++ -std=c++17 main.cpp -o app
./app
```
"""
    return {
        "main.cpp": script,
        "README.md": readme,
    }


def _arquivos_por_ideia(prompt: str, language: str) -> dict[str, str]:
    kind = _inferir_tipo_projeto(prompt, language)
    title = _titulo_ideia(prompt, kind)

    if language == "html_css_js":
        if kind == "login":
            return {
                "index.html": LOGIN_HTML,
                "style.css": LOGIN_CSS,
                "script.js": LOGIN_JS,
                "README.md": README_SITE,
            }
        if kind == "dashboard":
            return {
                "index.html": ADMIN_HTML,
                "style.css": ADMIN_CSS,
                "script.js": ADMIN_JS,
                "README.md": README_ADMIN,
            }
        if kind == "estoque":
            return {
                "index.html": ESTOQUE_HTML,
                "style.css": ESTOQUE_CSS,
                "script.js": ESTOQUE_JS,
                "README.md": README_ESTOQUE,
            }
        return _template_web_generico(title, prompt)

    if language == "javascript":
        return _template_javascript(prompt, title)
    if language == "java":
        return _template_java(prompt, title)
    if language == "cpp":
        return _template_cpp(prompt, title)
    if kind == "python_api":
        return {
            "app.py": API_FASTAPI,
            "requirements.txt": REQUIREMENTS_FASTAPI,
            "README.md": README_API,
        }
    return _template_python(prompt, title)


def _instrucoes_execucao(language: str, kind: str) -> list[str]:
    if language == "html_css_js":
        return ["Abra `index.html` no navegador para visualizar a interface."]
    if language == "javascript":
        return ["Execute `node app.js` dentro da pasta do projeto."]
    if language == "java":
        return ["Compile com `javac Main.java` e rode com `java Main`."]
    if language == "cpp":
        return ["Compile com `g++ -std=c++17 main.cpp -o app` e rode com `./app`."]
    if kind == "python_api":
        return [
            "Instale as dependencias com `pip install -r requirements.txt`.",
            "Suba a API com `uvicorn app:app --reload`.",
        ]
    return ["Execute `python main.py` dentro da pasta do projeto."]


def _melhorias_sugeridas(language: str, kind: str) -> list[str]:
    if language == "html_css_js":
        return [
            "Conectar a interface a um backend real.",
            "Adicionar validacoes e estados de carregamento.",
            "Separar componentes visuais para escalar a tela.",
        ]
    if language == "javascript":
        return [
            "Organizar a logica em modulos.",
            "Adicionar testes para funcoes criticas.",
            "Preparar integracao com API ou banco.",
        ]
    if language == "java":
        return [
            "Separar classes por responsabilidade.",
            "Adicionar testes unitarios com JUnit.",
            "Preparar build com Maven ou Gradle.",
        ]
    if language == "cpp":
        return [
            "Separar headers e implementacoes.",
            "Adicionar configuracao com CMake.",
            "Cobrir fluxos principais com testes.",
        ]
    if kind == "python_api":
        return [
            "Adicionar persistencia de dados.",
            "Criar autenticacao para as rotas.",
            "Separar schemas, servicos e repositorios.",
        ]
    return [
        "Separar regras em modulos menores.",
        "Adicionar testes automatizados.",
        "Preparar configuracoes por ambiente.",
    ]


def _montar_bundle_codigo(project_dir: Path, files: list[str]) -> str:
    bundle_parts: list[str] = []
    for relative_name in files:
        clean_name = str(relative_name).strip()
        if not clean_name or clean_name.lower().startswith("readme"):
            continue
        path = project_dir / clean_name
        if not path.exists() or not path.is_file():
            continue
        try:
            content = path.read_text(encoding="utf-8")
        except Exception:
            continue
        bundle_parts.append(f"// arquivo: {clean_name}\n{content.strip()}")
    return "\n\n".join(bundle_parts).strip()


def gerar_codigo_por_ideia(
    prompt: str,
    *,
    language: str = "",
    project_name: str = "",
    base_dir: str | Path | None = None,
) -> dict[str, object]:
    idea = _limpar_prefixo_nova(prompt).strip()
    if not idea:
        raise ValueError("prompt_empty")

    chosen_language = _inferir_linguagem(idea, preferred=language)
    kind = _inferir_tipo_projeto(idea, chosen_language)
    chosen_project_name = _nome_projeto_ideia(idea, chosen_language, project_name)
    files = _arquivos_por_ideia(idea, chosen_language)
    payload = criar_estrutura(chosen_project_name, files, base_dir=base_dir)
    file_list = [*payload.get("created_files", []), *payload.get("preserved_files", [])]
    run_steps = _instrucoes_execucao(chosen_language, kind)
    improvements = _melhorias_sugeridas(chosen_language, kind)
    language_label = _LANGUAGE_LABELS.get(chosen_language, chosen_language)
    project_ref = f"projetos_gerados/{payload['project_name']}"
    code_bundle = _montar_bundle_codigo(
        Path(payload["project_dir"]),
        [str(item) for item in file_list],
    )

    answer_lines = [
        f"Entendi sua ideia: {idea}.",
        f"Linguagem escolhida: {language_label}.",
        f"Arquivos gerados em: {project_ref}.",
        f"Arquivos principais: {formatar_lista_arquivos(file_list)}.",
        "",
        "Como executar:",
        *[f"- {step}" for step in run_steps],
        "",
        "Melhorias sugeridas:",
        *[f"- {item}" for item in improvements],
    ]
    answer = "\n".join(answer_lines).strip()

    return {
        "language": chosen_language,
        "language_label": language_label,
        "project_name": payload["project_name"],
        "project_dir": str(payload["project_dir"]),
        "project_ref": project_ref,
        "files": file_list,
        "run_instructions": run_steps,
        "improvements": improvements,
        "code_bundle": code_bundle,
        "copy_label": "Copiar codigo",
        "summary": f"Projeto {language_label} gerado em {project_ref}.",
        "answer": answer,
    }


def criar_site(nome_projeto: str = "site_nova", *, base_dir: str | Path | None = None) -> str:
    payload = criar_estrutura(
        nome_projeto,
        {
            "index.html": HTML_BASICO,
            "style.css": CSS_BASICO,
            "script.js": JS_BASICO,
            "README.md": README_SITE,
        },
        base_dir=base_dir,
    )
    return _resumo_criacao("Site", payload)


def criar_api(
    nome_projeto: str = "api_nova",
    *,
    stack: str = "flask",
    base_dir: str | Path | None = None,
) -> str:
    stack_normalizada = _normalizar(stack)
    if "fastapi" in stack_normalizada:
        arquivos = {
            "app.py": API_FASTAPI,
            "requirements.txt": REQUIREMENTS_FASTAPI,
            "README.md": README_API,
        }
        titulo = "API FastAPI"
    else:
        arquivos = {
            "app.py": API_FLASK,
            "requirements.txt": REQUIREMENTS_FLASK,
            "README.md": README_API,
        }
        titulo = "API Python"

    payload = criar_estrutura(nome_projeto, arquivos, base_dir=base_dir)
    return _resumo_criacao(titulo, payload)


def criar_api_com_banco(
    nome_projeto: str = "api_nova_db",
    *,
    base_dir: str | Path | None = None,
) -> str:
    payload = criar_estrutura(
        nome_projeto,
        {
            "app.py": API_FLASK_SQLITE,
            "requirements.txt": REQUIREMENTS_FLASK_SQLITE,
            "README.md": README_API_DB,
        },
        base_dir=base_dir,
    )
    return _resumo_criacao("API com banco de dados", payload)


def criar_sistema_login(
    nome_projeto: str = "sistema_login",
    *,
    base_dir: str | Path | None = None,
) -> str:
    payload = criar_estrutura(
        nome_projeto,
        {
            "index.html": LOGIN_HTML,
            "style.css": LOGIN_CSS,
            "script.js": LOGIN_JS,
            "README.md": README_SITE,
        },
        base_dir=base_dir,
    )
    return _resumo_criacao("Sistema de login", payload)


def criar_sistema_estoque(
    nome_projeto: str = "sistema_estoque",
    *,
    base_dir: str | Path | None = None,
) -> str:
    payload = criar_estrutura(
        nome_projeto,
        {
            "index.html": ESTOQUE_HTML,
            "style.css": ESTOQUE_CSS,
            "script.js": ESTOQUE_JS,
            "README.md": README_ESTOQUE,
        },
        base_dir=base_dir,
    )
    return _resumo_criacao("Sistema de estoque", payload)


def criar_painel_admin(
    nome_projeto: str = "painel_admin",
    *,
    base_dir: str | Path | None = None,
) -> str:
    payload = criar_estrutura(
        nome_projeto,
        {
            "index.html": ADMIN_HTML,
            "style.css": ADMIN_CSS,
            "script.js": ADMIN_JS,
            "README.md": README_ADMIN,
        },
        base_dir=base_dir,
    )
    return _resumo_criacao("Painel administrativo", payload)


def menu_desenvolvedor() -> str:
    return (
        "Modo desenvolvedor da NOVA ativado.\n\n"
        "Eu posso ajudar com:\n\n"
        "1. Criar site básico\n"
        "Comando: Nova, criar site\n\n"
        "2. Criar API Python\n"
        "Comando: Nova, criar API\n\n"
        "3. Criar sistema de login\n"
        "Comando: Nova, criar sistema de login\n\n"
        "4. Criar sistema de estoque\n"
        "Comando: Nova, criar sistema de estoque\n\n"
        "5. Criar API com banco de dados\n"
        "Comando: Nova, criar API com banco de dados\n\n"
        "6. Criar painel administrativo\n"
        "Comando: Nova, criar painel administrativo\n\n"
        "7. Explicar código\n"
        "Comando: Nova, explique este código: <cole o trecho>\n\n"
        "8. Corrigir erro\n"
        "Comando: Nova, corrija este erro: <cole o erro>\n\n"
        "Antes de escrever arquivos, eu peço confirmação. Para seguir, responda: confirmar criação.\n"
        "Tudo é gerado dentro da pasta projetos_gerados."
    )


def _extrair_conteudo(texto: str, gatilhos: tuple[str, ...]) -> str:
    bruto = _limpar_prefixo_nova(texto)
    normalizado = _normalizar(bruto)
    for gatilho in gatilhos:
        if gatilho in normalizado:
            indice = normalizado.find(gatilho)
            trecho_original = bruto[indice + len(gatilho) :].strip(" :\n\t-")
            return trecho_original
    return ""


def _contexto_dev(contexto: dict | None) -> dict:
    return contexto if isinstance(contexto, dict) else {}


def _salvar_pendencia_dev(contexto: dict, pendencia: dict[str, object]) -> None:
    contexto["dev_pending_action"] = pendencia


def _limpar_pendencia_dev(contexto: dict) -> None:
    if isinstance(contexto, dict):
        contexto.pop("dev_pending_action", None)


def _obter_pendencia_dev(contexto: dict | None) -> dict[str, object] | None:
    if not isinstance(contexto, dict):
        return None
    pendencia = contexto.get("dev_pending_action")
    return pendencia if isinstance(pendencia, dict) else None


def _texto_confirma(normalizado: str) -> bool:
    confirmacoes = (
        "confirmar criacao",
        "confirmar criação",
        "confirmar",
        "pode criar",
        "pode gerar",
        "sim pode criar",
        "sim pode gerar",
        "sim",
        "prosseguir",
    )
    return any(expr == normalizado or normalizado.startswith(expr + " ") for expr in confirmacoes)


def _texto_cancela(normalizado: str) -> bool:
    cancelamentos = (
        "cancelar criacao",
        "cancelar criação",
        "cancelar",
        "nao criar",
        "não criar",
        "deixa pra la",
        "deixa pra lá",
    )
    return any(expr == normalizado or normalizado.startswith(expr + " ") for expr in cancelamentos)


def _montar_pendencia(
    *,
    action: str,
    project_name: str,
    title: str,
    kwargs: dict[str, object] | None = None,
    base_dir: str | Path | None = None,
) -> dict[str, object]:
    pasta_raiz = pasta_projetos_gerados(base_dir)
    return {
        "action": action,
        "project_name": project_name,
        "title": title,
        "kwargs": kwargs or {},
        "preview_path": str((pasta_raiz / project_name).resolve()),
    }


def _executar_pendencia(pendencia: dict[str, object], *, base_dir: str | Path | None = None) -> str:
    action = str(pendencia.get("action", "") or "")
    project_name = str(pendencia.get("project_name", "") or "")
    kwargs = dict(pendencia.get("kwargs", {}) or {})

    if action == "site":
        return criar_site(project_name, base_dir=base_dir)
    if action == "api":
        return criar_api(project_name, stack=str(kwargs.get("stack", "flask")), base_dir=base_dir)
    if action == "api_db":
        return criar_api_com_banco(project_name, base_dir=base_dir)
    if action == "login":
        return criar_sistema_login(project_name, base_dir=base_dir)
    if action == "estoque":
        return criar_sistema_estoque(project_name, base_dir=base_dir)
    if action == "painel_admin":
        return criar_painel_admin(project_name, base_dir=base_dir)
    if action == "generic_generate":
        generated = gerar_codigo_por_ideia(
            str(kwargs.get("prompt", "") or project_name),
            language=str(kwargs.get("language", "") or ""),
            project_name=project_name,
            base_dir=base_dir,
        )
        return str(generated.get("answer", "")).strip() or "Projeto gerado com sucesso."
    return "Não consegui executar a criação pendente."


def _pedir_confirmacao(pendencia: dict[str, object]) -> str:
    titulo = str(pendencia.get("title", "Projeto"))
    preview_path = str(pendencia.get("preview_path", ""))
    return (
        f"Posso criar {titulo} em:\n{preview_path}\n\n"
        "Se estiver tudo certo, responda: confirmar criação"
    )


def processar_comando_dev(
    comando: str,
    *,
    contexto: dict | None = None,
    base_dir: str | Path | None = None,
) -> str | None:
    bruto = _limpar_prefixo_nova(comando)
    normalizado = _normalizar(bruto)
    if not normalizado:
        return None
    ctx = _contexto_dev(contexto)
    pendencia = _obter_pendencia_dev(ctx)

    if pendencia and _texto_confirma(normalizado):
        _limpar_pendencia_dev(ctx)
        return _executar_pendencia(pendencia, base_dir=base_dir)

    if pendencia and _texto_cancela(normalizado):
        _limpar_pendencia_dev(ctx)
        return "Criação cancelada. Quando quiser, eu preparo outro projeto para você."

    if any(chave in normalizado for chave in ("modo desenvolvedor", "desenvolver sistema")):
        return menu_desenvolvedor()

    if re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bsite\b", normalizado):
        nome = _extrair_nome_projeto(bruto, rf".*\b{_VERBOS_CRIACAO}\b.*\bsite\b", "site_nova")
        nova_pendencia = _montar_pendencia(
            action="site",
            project_name=nome,
            title="um site",
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if (
        re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bapi\b", normalizado)
        and "banco de dados" in normalizado
    ):
        nome = _extrair_nome_projeto(
            bruto,
            rf".*\b{_VERBOS_CRIACAO}\b.*\bapi\b.*\bbanco de dados\b",
            "api_nova_db",
        )
        nova_pendencia = _montar_pendencia(
            action="api_db",
            project_name=nome,
            title="uma API com banco de dados",
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bapi\b", normalizado):
        nome = _extrair_nome_projeto(bruto, rf".*\b{_VERBOS_CRIACAO}\b.*\bapi\b", "api_nova")
        stack = "fastapi" if "fastapi" in normalizado else "flask"
        titulo = "uma API FastAPI" if stack == "fastapi" else "uma API Python"
        nova_pendencia = _montar_pendencia(
            action="api",
            project_name=nome,
            title=titulo,
            kwargs={"stack": stack},
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bsistema de login\b", normalizado):
        nome = _extrair_nome_projeto(
            bruto,
            rf".*\b{_VERBOS_CRIACAO}\b.*\bsistema de login\b",
            "sistema_login",
        )
        nova_pendencia = _montar_pendencia(
            action="login",
            project_name=nome,
            title="um sistema de login",
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bsistema de estoque\b", normalizado):
        nome = _extrair_nome_projeto(
            bruto,
            rf".*\b{_VERBOS_CRIACAO}\b.*\bsistema de estoque\b",
            "sistema_estoque",
        )
        nova_pendencia = _montar_pendencia(
            action="estoque",
            project_name=nome,
            title="um sistema de estoque",
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if re.search(rf"\b{_VERBOS_CRIACAO}\b.*\bpainel administrativo\b", normalizado):
        nome = _extrair_nome_projeto(
            bruto,
            rf".*\b{_VERBOS_CRIACAO}\b.*\bpainel administrativo\b",
            "painel_admin",
        )
        nova_pendencia = _montar_pendencia(
            action="painel_admin",
            project_name=nome,
            title="um painel administrativo",
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    if any(chave in normalizado for chave in ("corrigir erro", "corrija este erro")):
        detalhe = _extrair_conteudo(bruto, ("corrigir erro", "corrija este erro"))
        if detalhe:
            return analisar_erro(detalhe)
        return "Cole o erro completo do terminal para eu analisar."

    if any(
        chave in normalizado
        for chave in ("explique este codigo", "explicar este codigo", "explique esse codigo")
    ):
        detalhe = _extrair_conteudo(
            bruto,
            ("explique este codigo", "explicar este codigo", "explique esse codigo"),
        )
        if detalhe:
            return explicar_codigo(detalhe)
        return "Cole o código completo para eu explicar de forma clara."

    if re.search(rf"\b{_VERBOS_CRIACAO}\b", normalizado) and any(
        token in normalizado for token in _GENERIC_DEV_HINTS
    ):
        language = _inferir_linguagem(bruto)
        project_name = _nome_projeto_ideia(bruto, language)
        language_label = _LANGUAGE_LABELS.get(language, language)
        nova_pendencia = _montar_pendencia(
            action="generic_generate",
            project_name=project_name,
            title=f"um projeto em {language_label}",
            kwargs={
                "prompt": bruto,
                "language": language,
            },
            base_dir=base_dir,
        )
        _salvar_pendencia_dev(ctx, nova_pendencia)
        return _pedir_confirmacao(nova_pendencia)

    return None
