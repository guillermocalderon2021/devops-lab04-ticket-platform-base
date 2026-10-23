# Ticket Platform - repositorio base del Laboratorio 4

Repositorio inicial para el laboratorio de Infraestructura como Código. La aplicación permite crear tickets, cambiar su estado y adjuntar evidencias. Los datos estructurados se almacenan en Azure Database for PostgreSQL Flexible Server y los archivos en Azure Blob Storage.

## Punto de partida

La infraestructura entregada es funcional pero deliberadamente limitada:

- un único ambiente;
- un único root module de Terraform;
- state local;
- sin módulos reutilizables;
- sin separación entre infraestructura compartida, desarrollo y producción;
- sin backend remoto configurado en Terraform;
- sin workflows de Terraform para plan o apply.

La aplicación, su CI y un workflow auxiliar para publicar las imágenes iniciales en Azure Container Registry ya están incluidos.

## Arquitectura inicial

```text
                        Azure Container Registry
                         /                   \
                        v                     v
              Frontend Container App   API Container App
                       |                     /       \
                       |                    v         v
                       |                PostgreSQL  Blob Storage
                       |                     ^
                       +------ /api ---------+
```

El frontend utiliza React y se sirve mediante nginx dentro de un Container App. Las solicitudes a `/api` son reenviadas por nginx hacia el Container App de la API.

## Configuración local

Los scripts no dependen de variables persistentes definidas en la sesión de terminal. La configuración local se mantiene en archivos excluidos de Git.

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
FRONTEND_IMAGE_NAME=ticket-frontend
IMAGE_TAG=baseline
```

Editar `terraform/secrets.auto.tfvars` y definir una contraseña válida para PostgreSQL.

## Secuencia para construir la línea base

### 1. Verificar herramientas y sesiones

```bash
./scripts/00-check-prerequisites.sh
```

El script verifica Azure CLI, Terraform, GitHub CLI, Git, Docker, Node.js y npm.

### 2. Crear el bootstrap

```bash
./scripts/01-bootstrap-azure.sh
```

El bootstrap crea fuera del Terraform evaluado:

- Storage Account y Blob Container destinados al state remoto que se utilizará posteriormente;
- managed identity de plan;
- managed identity de apply;
- RBAC base para ambas identidades;
- acceso `Storage Blob Data Contributor` para el usuario que ejecuta el bootstrap sobre la cuenta de state, necesario para migrar y verificar el backend mediante Microsoft Entra ID.

Los valores descubiertos o generados quedan en `config/bootstrap.env`, excluido de Git.

El Blob Container `tfstate` queda inicialmente vacío porque la línea base continúa utilizando state local.

### 3. Configurar OIDC y GitHub

```bash
./scripts/02-configure-oidc.sh
./scripts/03-configure-github.sh
```

Se configuran las federated identity credentials, GitHub Environments y las variables requeridas por GitHub Actions. También se publican los object IDs de las identidades de plan y apply para que puedan utilizarse posteriormente en la configuración Terraform.

### 4. Generar los archivos locales de Terraform

```bash
./scripts/04-prepare-terraform-files.sh
```

El script combina `config/lab.env` y `config/bootstrap.env` para crear `terraform/terraform.tfvars`. Las credenciales sensibles permanecen en `terraform/secrets.auto.tfvars`.

### 5. Registrar Azure Container Registry y crear ACR

Antes de ejecutar el script 05, registrar el resource provider requerido:

```bash
az provider register \
  --namespace Microsoft.ContainerRegistry \
  --wait
```

Verificar:

```bash
az provider show \
  --namespace Microsoft.ContainerRegistry \
  --query registrationState \
  --output tsv
```

El resultado debe ser `Registered`.

Después ejecutar:

```bash
./scripts/05-provision-registry.sh
```

Esta primera aplicación parcial resuelve la dependencia de arranque entre ACR y Container Apps. El script crea:

- Azure Container Registry;
- identidad de runtime utilizada por los Container Apps para descargar imágenes;
- `AcrPull` para esa identidad;
- `AcrPush` para la identidad de GitHub Actions.

ACR mantiene deshabilitadas las credenciales administrativas.

### 6. Publicar las imágenes iniciales

```bash
./scripts/06-publish-initial-image.sh
```

El script dispara `.github/workflows/publish-images.yml`. El workflow:

1. se autentica en Azure mediante OIDC;
2. autentica Docker contra ACR;
3. construye y publica `ticket-api:baseline`;
4. construye y publica `ticket-frontend:baseline`.

No se requiere una imagen preparada por el docente ni un registry externo.

### 7. Registrar los providers del despliegue completo

Antes del despliegue inicial registrar:

```bash
az provider register \
  --namespace Microsoft.DBforPostgreSQL \
  --wait
```

```bash
az provider register \
  --namespace Microsoft.App \
  --wait
```

Verificar ambos estados antes de continuar:

```bash
az provider show \
  --namespace Microsoft.DBforPostgreSQL \
  --query registrationState \
  --output tsv

az provider show \
  --namespace Microsoft.App \
  --query registrationState \
  --output tsv
```

### 8. Completar el despliegue inicial

```bash
./scripts/07-deploy-initial.sh
```

Terraform crea el resto de la infraestructura:

- PostgreSQL Flexible Server y la base de datos `tickets`;
- Storage Account y Blob Container `evidence`;
- Container Apps Environment;
- Container App de la API;
- Container App del frontend.

Los dos Container Apps descargan sus imágenes privadas desde ACR mediante una managed identity con `AcrPull`.

## Comprobaciones de línea base

Antes de modificar Terraform debe verificarse que:

1. el frontend es accesible;
2. se puede crear un ticket;
3. el ticket permanece disponible después de recargar;
4. puede cambiarse su estado;
5. puede adjuntarse un archivo;
6. el archivo puede descargarse posteriormente;
7. las imágenes `ticket-api` y `ticket-frontend` existen en ACR;
8. el contenedor `tfstate` existe y permanece vacío.

## Reproducibilidad

El repositorio versiona:

- `api/package-lock.json`;
- `frontend/package-lock.json`;
- `terraform/.terraform.lock.hcl`.

GitHub Actions utiliza `npm ci` para instalar exactamente las dependencias resueltas en los lockfiles.

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

El uso de `-target` en `05-provision-registry.sh` se limita al bootstrap de la línea base para resolver la dependencia inicial entre ACR y las imágenes requeridas por Container Apps. No constituye el flujo normal de Terraform. Después de publicar las imágenes, el despliegue se completa con un `terraform apply` normal.
