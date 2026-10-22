# Instalar Daily Office (guía para Claude)

Pega esto en Claude Code en el Mac del usuario:

```text
Instala Daily Office en mi Mac siguiendo las instrucciones de https://github.com/emilianocros27-bit/Daily-Office/blob/main/CLAUDE.md
```

Eres Claude instalando Daily Office (app de macOS, https://github.com/emilianocros27-bit/Daily-Office) para la persona que te escribe. Habla en español, paso a paso y con frases cortas.

## Requisitos

Comprueba cada uno antes de empezar:

| Requisito | Comando | Debe mostrar |
|---|---|---|
| macOS 14 o posterior | `sw_vers -productVersion` | 14.0 o más |
| Xcode | `xcodebuild -version` | una versión (probado con 27; 15.3+ no verificado) |
| Git | `git --version` | una versión |
| Codex (opcional) | `which codex` | una ruta |

Si falta Xcode, dile que lo instale desde la App Store y vuelve a comprobar. No lo instales tú.

## Pasos

1. **Avisa antes de tocar el sistema.** Di que vas a clonar el repo, compilarlo y copiar `Daily Office.app` a `/Applications`. Espera un sí.
2. **Pregunta dónde clonar** (por defecto `~/Developer`). Crea la carpeta si no existe.
3. **Clona:**
   ```sh
   git clone https://github.com/emilianocros27-bit/Daily-Office.git
   cd Daily-Office
   ```
4. **Compila:**
   ```sh
   xcodebuild -project DailyOffice.xcodeproj -scheme DailyOffice -configuration Release -derivedDataPath build CODE_SIGNING_ALLOWED=NO build
   ```
   Debe terminar con `BUILD SUCCEEDED`.
5. **Instala** (si ya existe una copia en `/Applications`, pregunta antes de reemplazarla):
   ```sh
   cp -R "build/Build/Products/Release/Daily Office.app" /Applications/
   xattr -dr com.apple.quarantine "/Applications/Daily Office.app"
   ```
6. **Abre:** `open "/Applications/Daily Office.app"`
7. **Codex (opcional).** Pregunta si quiere usar Codex. Si sí y `which codex` está vacío: `npm install -g @openai/codex`, luego pídele que ejecute `codex login` (abre el navegador y debe hacerlo él).
8. **Claves de API (opcional).** Pregunta qué proveedor usa. Dile que las pegue en la app (Configuración → agente). Nunca las pidas en el chat ni las escribas en archivos.
9. **Opcional:** corre `swift test` y comunica el resultado.

## Qué preguntar a la persona

- ¿Dónde clonar el repo?
- ¿Reemplazar una instalación existente?
- ¿Usará Codex, una API o ambos?
- ¿Qué carpeta de proyecto quiere conectar? Solo la elige ella en la app.

## Cómo confirmar que funciona

Pídele que confirme cada punto con lo que ve:

1. Aparece un icono de cuatro círculos en la barra de menús.
2. Al acercar el cursor a la pestaña inferior se despliega el dock con siete agentes.
3. Al hacer clic en un agente se abre su ventana de chat.
4. Con Codex: General → **Comprobar conexión** muestra que está conectado.

Permisos que macOS pedirá más adelante: Grabación de pantalla (al usar el visor) y Automatización de Terminal (al pulsar «Ejecutar proyecto»). Avisa antes de que aparezcan y explica que debe aceptarlos ella.

## Si algo falla

| Síntoma | Qué hacer |
|---|---|
| `xcodebuild` dice que no hay Xcode completo | `sudo xcode-select -s /Applications/Xcode.app` (pide permiso antes; requiere contraseña de la persona) |
| Aviso de licencia de Xcode | Pide que ejecute `sudo xcodebuild -license accept` ella misma |
| `BUILD FAILED` | Muestra el primer `error:` literal, no reintentes en bucle; propón abrir el proyecto en Xcode |
| macOS bloquea la app | Repite `xattr -dr com.apple.quarantine "/Applications/Daily Office.app"` |
| No encuentra Codex | `which codex`; si está en otra ruta, instala con `npm install -g @openai/codex` o crea el enlace en `/usr/local/bin` (avisa antes) |
| Captura vacía | Ajustes del Sistema → Privacidad y seguridad → Grabación de pantalla → activar Daily Office y reabrir |

Si tras dos intentos no avanza, para, explica qué probaste y pregunta cómo seguir.

## Reglas

- Pide confirmación antes de: escribir fuera de la carpeta clonada, copiar a `/Applications`, usar `sudo`, instalar paquetes globales.
- No leas ni modifiques el Llavero, `~/Library/Application Support/DailyOffice` ni archivos personales.
- No hagas commit ni push en este repo salvo que te lo pidan.

## Para quien modifique el código

- `DailyOffice/Models.swift`: agentes, modelos de datos, `CodexLocator`.
- `DailyOffice/Services.swift`: Codex y proveedores de API.
- `generate_project.py` regenera `DailyOffice.xcodeproj`; no edites el `.pbxproj` a mano.
- `swift test` cubre `Models`, `Services` y `OfficeStore`.
