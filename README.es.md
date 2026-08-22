# Omarchy Keyguide

[English](README.md) · [한국어](README.ko.md) · [简体中文](README.zh-CN.md) · [日本語](README.ja.md) · [Español](README.es.md)

> Repositorio público: <https://github.com/mrai125kr/omarchy-keyguide>

Omarchy Keyguide es un complemento para Omarchy que muestra los atajos activos
en un HUD que no interfiere con la entrada. También permite registrar,
modificar y eliminar atajos dentro de un conjunto deliberadamente limitado y
seguro.

## Objetivo y usuarios

Keyguide ayuda a quienes empiezan con Omarchy a descubrir lo que hace cada
combinación sin memorizar una lista larga ni revisar archivos de configuración.
También ofrece a los usuarios con experiencia una vista rápida y buscable de
los atajos que están realmente activos y de las aplicaciones instaladas en el
equipo actual.

Puedes usar Keyguide para:

- mantener pulsada una combinación con `Super` y ver los atajos disponibles;
- buscar acciones generales en inglés o en el idioma seleccionado;
- encontrar aplicaciones gráficas instaladas y comandos en el mismo selector;
- mover, sustituir, eliminar o restaurar atajos compatibles con detección de
  conflictos;
- ajustar la posición, escala, opacidad, tema y filas visibles del HUD.

Keyguide no es un grabador de macros ni un editor sin restricciones para la
configuración de Hyprland. Solo permite modificar acciones que puede reconstruir
y verificar de forma segura.

## Funciones principales

- Posición, escala, opacidad, seguimiento del tema, grupos y filas del HUD
- Interfaz y HUD en inglés (predeterminado), coreano, japonés, chino simplificado
  y español
- Registro de una tecla libre en una ventana centrada y edición o eliminación
  de una tecla existente junto a su fila
- Búsqueda conjunta de acciones generales, aplicaciones instaladas y comandos
- Icono de escritorio para aplicaciones y distintivo `(CMD)` para comandos
- Búsqueda de acciones generales tanto en inglés como en el idioma seleccionado
- Actualización automática de aplicaciones instaladas o eliminadas mientras el
  selector está abierto
- Detección de conflictos con todos los atajos de Hyprland, incluidos los que
  no aparecen en el menú
- Restauración exacta si hay un conflicto, un cambio simultáneo o un error al
  recargar
- Restablecimiento de los atajos originales movidos y eliminación de los atajos
  creados por Keyguide

## Requisitos y compatibilidad

El entorno previsto es Omarchy `4.0.0-1` con Hyprland `0.56.2` o posterior.
Además del entorno estándar de Omarchy, se necesitan Python 3, `xkbcli` y acceso
a un dispositivo de eventos de teclado legible. La primera instalación desde
el código fuente o como complemento Git necesita un compilador de C, incluido
en `base-devel` para Arch Linux.

Comprueba la compatibilidad desde la raíz del repositorio:

```sh
PYTHONPATH=src/backend python -m keyguide_backend compat
```

El comando devuelve JSON con las versiones detectadas, la disponibilidad del
dispositivo de teclado y cualquier error. Termina con un código distinto de
cero cuando el sistema no es compatible.

## Instalación y uso

### Complemento Git de Omarchy — recomendado

```sh
omarchy plugin add https://github.com/mrai125kr/omarchy-keyguide.git --enable
```

Durante la primera activación se compila un pequeño observador de entrada que
no captura las teclas a partir del código C incluido en el repositorio. Puede
tardar un momento y no descarga ningún ejecutable externo. Cuando aparezca el
icono de Keyguide en la barra superior, púlsalo para abrir los controles rápidos
o la configuración completa.

### Primer uso

1. Abre la configuración completa desde el icono de Keyguide en la barra.
2. Elige el idioma. El inglés es el predeterminado; también se incluyen coreano,
   japonés, chino simplificado y español.
3. Configura la posición, escala, opacidad, seguimiento del tema y grupos de
   modificadores visibles.
4. Mantén pulsado `Super`, solo o junto con Ctrl, Shift y/o Alt, para mostrar los
   atajos activos de esa combinación exacta.
5. En la edición de atajos, selecciona una tecla libre para abrir el registro en
   el centro. Usa `Cambiar` junto a una fila existente para editarla o `Eliminar`
   para dejar libre esa tecla.
6. `Restablecer todo` recupera los atajos originales que se pueden restaurar y
   elimina los creados por Keyguide sin restablecer otros ajustes de Omarchy.

### Buscar y registrar acciones

El mismo campo busca acciones generales, aplicaciones instaladas y comandos.
Las acciones generales se encuentran tanto por su nombre inglés como por el
idioma actual. Las aplicaciones muestran su icono de escritorio y los comandos
muestran `(CMD)`. Los argumentos opcionales solo aparecen al elegir un comando.

Si registras una acción existente en otra tecla, Keyguide la mueve en lugar de
duplicarla. Antes de sustituir una tecla ocupada, muestra el nombre de la acción
que se eliminará y solicita una segunda confirmación. Las acciones que no se
pueden reconstruir con seguridad permanecen en modo de solo lectura con una
explicación.

### Actualización

```sh
omarchy plugin update mrai.keyguide --yes
```

Omarchy muestra las diferencias y realiza una actualización de avance rápido.
Si hay cambios locales que lo impiden, consérvalos o revísalos antes de
actualizar.

### Eliminación

```sh
omarchy plugin remove mrai.keyguide
```

Al eliminar el complemento Git también se borra la compilación generada dentro
del repositorio. De forma predeterminada se conservan las preferencias de
presentación y el módulo de atajos gestionado por separado para reutilizarlos
después de una actualización o reinstalación.

### Instalación y eliminación desde el código fuente

```sh
make test
make install
```

Para actualizar una instalación existente conservando la configuración del
shell del usuario:

```sh
PRESERVE_USER_SHELL=1 make install
```

Para eliminar únicamente los archivos autenticados por el manifiesto de
instalación:

```sh
make uninstall
```

Para restablecer también los atajos gestionados por Keyguide y sus preferencias
antes de eliminarlo, declara esa intención de forma explícita:

```sh
REMOVE_PREFERENCES=1 make uninstall
```

## Seguridad y privacidad

- El observador no captura, consume ni reproduce teclas, y no registra lo que
  escribes.
- Keyguide no modifica `~/.config/hypr/bindings.lua`.
- El módulo generado solo cambia cuando el usuario confirma una modificación de
  atajo.
- Los conflictos y el resultado se verifican antes de guardar, después de
  recargar Hyprland y en el estado real de ejecución.
- Si algo falla, se restauran exactamente los bytes anteriores y no queda una
  configuración parcial.
- No se recopilan ni guardan contraseñas, tokens de API, datos de cuentas ni
  datos de red.
- El desinstalador no elimina archivos fuera del registro autenticado ni cambios
  independientes del usuario.

Los cambios de atajos se guardan en
`~/.local/state/omarchy/toggles/hypr/omarchy-keyguide.lua` y las preferencias
del HUD en `~/.local/share/omarchy-keyguide/settings.json`.

## Solución de problemas

- Ejecuta primero la comprobación de compatibilidad para ver la causa exacta.
- Si falta el compilador, ejecuta `omarchy pkg add base-devel` y vuelve a instalar
  o actualizar.
- Si el HUD no detecta teclas mantenidas, comprueba en el resultado si hay un
  dispositivo de eventos de teclado legible.
- Si el complemento está instalado pero no aparece la interfaz, ejecuta
  `omarchy restart shell` y vuelve a intentarlo.
- Valida un árbol de código descargado con `omarchy plugin validate .`.
- Keyguide rechaza teclas duplicadas, acciones ambiguas, teclas no compatibles y
  cambios externos simultáneos, y muestra el motivo en vez de guardar un estado
  parcial.

## Desarrollo y verificación

```sh
make test
make build
```

`make test` ejecuta la verificación automática no destructiva. `make build`
compila el observador y comprueba el backend de Python.

## Licencia

Licencia MIT. Consulta [LICENSE](LICENSE) y [NOTICE](NOTICE) para obtener más
información.
