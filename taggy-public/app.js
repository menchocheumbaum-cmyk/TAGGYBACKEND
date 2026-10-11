async function cargarMascota() {

    try {

        const partes = window.location.pathname.split("/");

        const token = partes[partes.length - 1];

        const respuesta = await fetch(
            `/api/public/pet/${token}`
        );

        if (!respuesta.ok) {
            throw new Error("Mascota no encontrada");
        }

        const datos = await respuesta.json();

        const mascota = datos.mascota;
        const contacto = datos.contacto;

        document.getElementById(
            "nombreMascota"
        ).textContent = mascota.nombre;

        document.getElementById(
            "tipoMascota"
        ).textContent =
            `${mascota.especie} · ${mascota.raza || ""}`;

        document.getElementById(
            "sexo"
        ).textContent =
            mascota.sexo || "No especificado";

        document.getElementById(
            "color"
        ).textContent =
            mascota.color || "No especificado";

        document.getElementById(
            "senas"
        ).textContent =
            mascota.senas_particulares ||
            "Sin información";

        document.getElementById(
            "propietario"
        ).textContent =
            `Propietario: ${contacto.nombre}`;

        const telefono =
            document.getElementById("telefono");

        telefono.href =
            `tel:${contacto.telefono}`;

        if (mascota.extraviada) {

            document
                .getElementById("alertaExtravio")
                .classList
                .remove("oculto");
        }

    } catch (error) {

        document.body.innerHTML = `
            <h2 style="text-align:center;margin-top:50px">
                Perfil TAGGY no disponible
            </h2>
        `;
    }
}

cargarMascota();
let ubicacionActual = {
    latitude: null,
    longitude: null,
    accuracy: null
};

const btnMostrar =
    document.getElementById("btnMostrarAvistamiento");

const formulario =
    document.getElementById("formAvistamiento");

const btnUbicacion =
    document.getElementById("btnUbicacion");

const estadoUbicacion =
    document.getElementById("estadoUbicacion");

const resultadoAvistamiento =
    document.getElementById("resultadoAvistamiento");


btnMostrar.addEventListener("click", () => {

    formulario.classList.toggle("oculto");

});


btnUbicacion.addEventListener("click", () => {

    if (!navigator.geolocation) {

        estadoUbicacion.textContent =
            "Tu navegador no permite obtener la ubicación.";

        return;
    }

    estadoUbicacion.textContent =
        "Obteniendo ubicación...";

    navigator.geolocation.getCurrentPosition(

        (position) => {

            ubicacionActual.latitude =
                position.coords.latitude;

            ubicacionActual.longitude =
                position.coords.longitude;

            ubicacionActual.accuracy =
                position.coords.accuracy;

            estadoUbicacion.textContent =
                "✅ Ubicación obtenida correctamente";
        },

        (error) => {

            console.error(error);

            estadoUbicacion.textContent =
                "No fue posible obtener tu ubicación. Puedes enviar el reporte sin ella.";
        },

        {
            enableHighAccuracy: true,
            timeout: 10000,
            maximumAge: 0
        }
    );
});


formulario.addEventListener("submit", async (event) => {

    event.preventDefault();

    resultadoAvistamiento.textContent =
        "Enviando reporte...";

    try {

        const partes =
            window.location.pathname.split("/");

        const token =
            partes[partes.length - 1];

        const body = {

            nombre:
                document
                    .getElementById("nombreReportante")
                    .value
                    .trim(),

            telefono:
                document
                    .getElementById("telefonoReportante")
                    .value
                    .trim(),

            mensaje:
                document
                    .getElementById("mensajeAvistamiento")
                    .value
                    .trim(),

            latitude:
                ubicacionActual.latitude,

            longitude:
                ubicacionActual.longitude,

            accuracy:
                ubicacionActual.accuracy
        };

        const respuesta = await fetch(
            `/api/public/pet/${token}/sighting`,
            {
                method: "POST",

                headers: {
                    "Content-Type": "application/json"
                },

                body: JSON.stringify(body)
            }
        );

        const datos =
            await respuesta.json();

        if (!respuesta.ok) {
            throw new Error(
                datos.mensaje ||
                "No se pudo enviar el reporte"
            );
        }

        resultadoAvistamiento.textContent =
            "✅ Avistamiento enviado correctamente";

        formulario.reset();

        ubicacionActual = {
            latitude: null,
            longitude: null,
            accuracy: null
        };

        estadoUbicacion.textContent = "";

    } catch (error) {

        console.error(error);

        resultadoAvistamiento.textContent =
            "❌ No se pudo enviar el avistamiento";
    }
});