# Ticket Platform - repositorio base del Laboratorio 4

Repositorio inicial para el laboratorio de Infraestructura como Código. La aplicación permite crear tickets, cambiar su estado y adjuntar evidencias. Los datos estructurados se almacenan en Azure Database for PostgreSQL Flexible Server y los archivos en Azure Blob Storage.

## Punto de partida

La infraestructura entregada es funcional pero deliberadamente limitada:

- un único ambiente;
- un único root module de Terraform;
- state local;
- sin módulos reutilizables;
- sin separación `shared`, `development` y `production`;
- sin workflows de Terraform.

La aplicación, su CI y un workflow auxiliar para publicar la imagen inicial en Azure Container Registry ya están incluidos. El ACR forma parte de la infraestructura creada por Terraform.

## Arquitectura inicial

```text
Static Web App
      |
      v
Container App <---- Azure Container Registry
   |       |
   v       v
PostgreSQL Blob Storage
```

## Configuración local

Los scripts no dependen de variables definidas en la sesión de terminal. Toda configuración local se mantiene en archivos excluidos de Git.

Crear:

```bash
cp config/lab.env.example config/lab.env
cp terraform/secrets.auto.tfvars.example terraform/secrets.auto.tfvars
```

Editar `config/lab.env`:

```text
AZURE_LOCATION=REGION_PERMITIDA
GITHUB_REPOSITORY=OWNER/REPOSITORY
IMAGE_NAME=ticket-api
IMAGE_TAG=baseline
```

Editar `terraform/secrets.auto.tfvars` y definir una contraseña válida para PostgreSQL.

Estos dos archivos están incluidos en `.gitignore`.

## Secuencia para construir la línea base

### 1. Verificar herramientas y sesiones

```bash
./scripts/00-check-prerequisites.sh
```

El script verifica Azure CLI, Terraform, GitHub CLI, Git, Docker, Node.js y npm, además de comprobar `config/lab.env`.

### 2. Crear el bootstrap

```bash
./scripts/01-bootstrap-azure.sh
```

El bootstrap crea fuera del Terraform evaluado:

- Storage Account y Blob Container destinados al state remoto que se utilizará posteriormente en el laboratorio;
- managed identity de plan;
- managed identity de apply;
- RBAC base para ambas identidades.

Los valores descubiertos o generados quedan en `config/bootstrap.env`, también excluido de Git.

### 3. Configurar OIDC y GitHub

```bash
./scripts/02-configure-oidc.sh
./scripts/03-configure-github.sh
```

Se configuran las federated identity credentials y las variables del repositorio requeridas por GitHub Actions.

### 4. Generar los archivos locales de Terraform

```bash
./scripts/04-prepare-terraform-files.sh
```

El script combina `config/lab.env` y `config/bootstrap.env` para crear `terraform/terraform.tfvars`. Las credenciales sensibles permanecen en `terraform/secrets.auto.tfvars`.

### 5. Crear ACR y los permisos necesarios

```bash
./scripts/05-provision-registry.sh
```

Esta primera aplicación parcial es necesaria por una dependencia de arranque: Container Apps necesita que la imagen exista antes de crear la aplicación. El script crea:

- Azure Container Registry;
- identidad de runtime utilizada por Container Apps para descargar imágenes;
- `AcrPull` para esa identidad;
- `AcrPush` para la identidad de GitHub Actions.

ACR tiene deshabilitadas las credenciales administrativas.

### 6. Publicar la imagen inicial mediante GitHub Actions

```bash
./scripts/06-publish-initial-image.sh
```

El script dispara `publish-api.yml`. El workflow:

1. se autentica en Azure mediante OIDC;
2. autentica Docker contra ACR;
3. construye `api/Dockerfile`;
4. publica la imagen `ticket-api:baseline` o el tag definido en `config/lab.env`.

No se requiere una imagen preparada por el docente ni un registry externo.

### 7. Completar el despliegue inicial

```bash
./scripts/07-deploy-initial.sh
```

Terraform crea el resto de la infraestructura, incluido Container Apps, PostgreSQL, Blob Storage y Static Web Apps. Container Apps utiliza una managed identity con `AcrPull` para descargar la imagen privada.

El script compila finalmente el frontend con la URL creada para la API y lo publica en Static Web Apps.

## Comprobaciones de línea base

Antes de modificar Terraform debe verificarse que:

1. el frontend es accesible;
2. se puede crear un ticket;
3. el ticket permanece disponible después de recargar;
4. puede cambiarse su estado;
5. puede adjuntarse un archivo;
6. el archivo puede descargarse posteriormente;
7. la imagen de la API existe en el ACR del equipo.

## Qué todavía no está resuelto

La línea base no incluye:

- `terraform/modules/`;
- infraestructura `shared`;
- ambientes `development` y `production`;
- backend remoto configurado en el código Terraform;
- workflows de `terraform plan` o `terraform apply`;
- el Blob Container `diagnostic-logs`.

Esos elementos forman parte de la evolución que se realizará durante el laboratorio.

## Nota sobre el primer apply parcial

El uso de `-target` en `05-provision-registry.sh` es exclusivamente una operación de bootstrap para resolver la dependencia inicial entre ACR y Container Apps. No constituye el flujo normal recomendado de Terraform. Después de publicar la imagen, el despliegue se completa con un `terraform apply` normal.
