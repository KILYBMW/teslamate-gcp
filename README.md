# Manual de despliegue: VM + Bucket en GCP con Terraform

Estos ficheros de Terraform despliegan una **VM de Compute Engine** y un **bucket de Cloud Storage** en Google Cloud Platform con la misma configuración de referencia. Lo único que necesitas personalizar son los **nombres** de cada recurso.

---

## Infraestructura que se despliega

| Recurso | Configuración |
|---|---|
| **VM** | e2-micro · 2 vCPU · 1 GB RAM |
| Zona | `us-west1-b` |
| Imagen | Debian 12 Bookworm (x86-64) |
| Disco arranque | 30 GB · pd-standard · lectura/escritura |
| Red | VPC `default` · Subred `default` · IPv4 |
| Firewall | Sin HTTP/HTTPS · Sin etiquetas de red |
| Disponibilidad | STANDARD · Auto-restart activo · Migrar en mantenimiento |
| **Software** | Docker, Docker Compose, Tailscale (vía Startup Script) |
| **Bucket** | Cloud Storage STANDARD |
| Región bucket | `US-WEST1` |
| Control de acceso | Uniform bucket-level access (IAM) |

---

## Requisitos previos y configuración inicial en GCP

Este despliegue está optimizado para ejecutarse desde **Google Cloud Shell**, donde Terraform y `gcloud` ya están preinstalados y autenticados.

### 1. Crear o seleccionar un proyecto de GCP

Si eres nuevo en GCP, necesitarás un proyecto.
*   Ve a la Consola de GCP.
*   En la barra superior, haz clic en el selector de proyectos y luego en "Nuevo proyecto".
*   Apunta el **ID de tu proyecto** (no el nombre). Lo encontrarás en:
    Consola GCP → Menú lateral → Inicio → columna **"ID del proyecto"**
<img width="1363" height="797" alt="image" src="https://github.com/user-attachments/assets/7a7edc36-64b2-4166-b1cc-7faf393facc4" />

### 2. Habilitar la facturación (Billing)

Para poder crear recursos en GCP, tu proyecto debe tener una cuenta de facturación activa.
*   Ve a la Consola de GCP → Menú de navegación → **Facturación**.
*   Si no tienes una cuenta de facturación, se te guiará para crear una. GCP ofrece un crédito gratuito inicial para nuevos usuarios.

### 3. Habilitar las APIs necesarias

Asegúrate de que las siguientes APIs están habilitadas en tu proyecto. Esto es crucial para que Terraform pueda interactuar con los servicios de Compute Engine y Cloud Storage.

```bash
gcloud services enable compute.googleapis.com storage.googleapis.com --project=TU_PROJECT_ID
```

---

## Pasos para desplegar

### Paso 1 — Clonar el repositorio en Cloud Shell

En la terminal de **Cloud Shell**, ejecuta el siguiente comando para descargar los archivos:

```bash
git clone https://github.com/TU_USUARIO/TU_REPOSITORIO.git instalar
cd instalar
```

> **Tip:** También puedes abrir este repositorio directamente haciendo clic en el siguiente enlace (reemplaza con tu URL):
> `https://ssh.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/TU_USUARIO/TU_REPOSITORIO`

### Paso 2 — Crear tu fichero de variables

Copia el fichero de ejemplo y rellena tus valores:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edita `terraform.tfvars` con un editor de texto:

```hcl
project_id  = "mi-proyecto-gcp-12345"   # ID real de tu proyecto
vm_name     = "mi-vm"                   # Nombre que quieras para la VM
bucket_name = "mi-bucket-unico-2024"    # Nombre globalmente único
```

> ⚠️ **El nombre del bucket debe ser único en todo GCP** (no solo en tu proyecto).
> Si el nombre ya existe, Terraform devolverá un error. Añade tu usuario, proyecto
> o un sufijo aleatorio para asegurarte: `mi-bucket-pepeg-2024`.

### Paso 3 — Inicializar Terraform

Desde la carpeta donde están los ficheros `.tf`:

```bash
terraform init
```

Esto descarga el provider de Google y prepara el entorno local. Solo es necesario hacerlo la primera vez (o si cambias de provider/versión).

### Paso 4 — Revisar el plan de despliegue

Antes de crear nada, revisa qué va a hacer Terraform:

```bash
terraform plan
```

Verás una lista de recursos que se van a crear. No se modifica nada todavía.

### Paso 5 — Aplicar el despliegue

```bash
terraform apply
```

Terraform mostrará de nuevo el plan y pedirá confirmación. Escribe `yes` y pulsa Enter.

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```

El despliegue tarda aproximadamente **1-2 minutos**. Al finalizar verás los outputs:

```
Outputs:

bucket_location  = "US-WEST1"
bucket_name      = "mi-bucket-unico-2024"
bucket_url       = "gs://mi-bucket-unico-2024"
vm_external_ip   = "34.xx.xx.xx"
vm_internal_ip   = "10.138.0.x"
vm_name          = "mi-vm"
vm_zone          = "us-west1-b"
```

---

## Conectarse a la VM

Una vez desplegada, puedes conectarte directamente desde gcloud:

```bash
gcloud compute ssh NOMBRE_DE_TU_VM --zone=us-west1-b --project=TU_PROJECT_ID
```

O desde la consola de GCP → Compute Engine → VM instances → botón **SSH**.

---

## Destruir la infraestructura

Cuando ya no necesites los recursos, elimínalos para evitar costes:

```bash
terraform destroy
```

Confirma con `yes`. Esto eliminará la VM y el bucket (si el bucket está vacío; si tiene objetos, Terraform fallará salvo que `force_destroy` esté en `true`).

---

## Preguntas frecuentes

**¿Puedo cambiar la región o zona?**
Sí, modificando las variables en `terraform.tfvars`. Sin embargo, ten en cuenta que la **Capa Gratuita de GCP (Free Tier)** para la instancia `e2-micro` y el almacenamiento regional solo aplica en regiones específicas (usualmente `us-west1`, `us-central1` y `us-east1`). Si cambias a otra región, incurrirás en gastos mensuales. Además, mantén el bucket y la VM en la misma región para evitar costes de transferencia de datos y latencia.

**¿La IP externa de la VM es fija?**
No, es efímera. Cambia cada vez que se reinicia la VM. Si necesitas una IP estática, debes reservar una IP estática en GCP y asociarla en el bloque `access_config` de `main.tf`.

**¿Quiero la VM sin IP externa (solo red interna)?**
Elimina el bloque `access_config {}` dentro de `network_interface` en `main.tf`.

**¿Qué pasa si el nombre del bucket ya existe?**
Terraform devolverá un error `409 Conflict`. Simplemente elige otro nombre en `terraform.tfvars`.

**¿Puedo tener varias instancias de esta infraestructura en el mismo proyecto?**
Sí. Asegúrate de que `vm_name` y `bucket_name` sean distintos en cada `terraform.tfvars`.

---

## Estructura del proyecto

```
main.tf              Define los recursos: VM y Bucket con toda su configuración.
variables.tf         Declara las tres variables configurables: project_id, vm_name, bucket_name.
outputs.tf           Muestra las IPs, URLs y nombres tras el despliegue.
terraform.tfvars     Tu fichero de valores (créalo desde el .example, no se sube a git).
```

> 🔒 **Seguridad:** No subas `terraform.tfvars` a repositorios públicos si contiene
> el ID de tu proyecto u otros datos sensibles. Añádelo al `.gitignore`.
