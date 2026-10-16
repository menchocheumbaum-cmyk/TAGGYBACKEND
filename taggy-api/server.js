const jwt = require("jsonwebtoken");

const bcrypt = require("bcryptjs");

const path = require("path");

const QRCode = require("qrcode");

const express = require("express");

const cors = require("cors");

const crypto = require("crypto");

const webpush = require("web-push");

require("dotenv").config();



const db = require("./db");



const app = express();



app.use(cors());

app.use(express.json());



app.use(

  express.static(

    path.join(__dirname, "../taggy-public")

  )

);




// ======================================================
// WEB PUSH / NOTIFICACIONES TAGGY
// ======================================================

function configurarWebPushTAGGY() {
  const publicKey = process.env.VAPID_PUBLIC_KEY;
  const privateKey = process.env.VAPID_PRIVATE_KEY;
  const subject = process.env.VAPID_SUBJECT;

  if (!publicKey || !privateKey || !subject) {
    console.warn(
      "Web Push desactivado: faltan variables VAPID"
    );
    return false;
  }

  webpush.setVapidDetails(
    subject,
    publicKey,
    privateKey
  );

  return true;
}

const webPushActivo = configurarWebPushTAGGY();

async function enviarPushUsuario(
  usuarioId,
  payload
) {
  if (!webPushActivo) {
    return {
      enviados: 0,
      eliminados: 0
    };
  }

  const resultado = await db.query(
    `
      SELECT
        id,
        endpoint,
        p256dh,
        auth
      FROM push_suscripciones
      WHERE usuario_id = $1
        AND activa = TRUE
    `,
    [usuarioId]
  );

  let enviados = 0;
  let eliminados = 0;

  for (const fila of resultado.rows) {
    const subscription = {
      endpoint: fila.endpoint,
      keys: {
        p256dh: fila.p256dh,
        auth: fila.auth
      }
    };

    try {
      await webpush.sendNotification(
        subscription,
        JSON.stringify(payload)
      );

      enviados++;
    } catch (error) {
      if (
        error.statusCode === 404 ||
        error.statusCode === 410
      ) {
        await db.query(
          `
            UPDATE push_suscripciones
            SET
              activa = FALSE,
              fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE id = $1
          `,
          [fila.id]
        );

        eliminados++;
      } else {
        console.error(
          "Error enviando Web Push:",
          error.statusCode || error.message
        );
      }
    }
  }

  return {
    enviados,
    eliminados
  };
}

function verificarToken(req, res, next) {

  const authHeader = req.headers.authorization;



  if (!authHeader) {

    return res.status(401).json({

      mensaje: "Token requerido"

    });

  }



  const partes = authHeader.split(" ");



  if (partes.length !== 2 || partes[0] !== "Bearer") {

    return res.status(401).json({

      mensaje: "Formato de token invÃ¡lido"

    });

  }



  const token = partes[1];



  try {

    const datos = jwt.verify(token, process.env.JWT_SECRET);



    req.usuario = datos;



    next();



  } catch (error) {

    return res.status(401).json({

      mensaje: "Token invÃ¡lido o expirado"

    });

  }

}



app.get("/", (req, res) => {

  res.json({

    proyecto: "TAGGY",

    mensaje: "API funcionando correctamente"

  });

});



app.get("/db-test", async (req, res) => {

  try {

    const resultado = await db.query("SELECT NOW() AS fecha");



    res.json({

      conexion: "correcta",

      baseDatos: process.env.DB_NAME,

      fechaServidor: resultado.rows[0].fecha

    });

  } catch (error) {

    console.error("Error PostgreSQL:", error);



    res.status(500).json({

      conexion: "error",

      mensaje: error.message

    });

  }

});



const PORT = process.env.PORT || 3000;

app.post("/api/usuarios", async (req, res) => {

  try {

    const {

      nombre,

      apellido,

      email,

      password,

      telefono

    } = req.body;



    if (!nombre || !email || !password) {

      return res.status(400).json({

        mensaje: "Nombre, email y password son obligatorios"

      });

    }



    const passwordHash = await bcrypt.hash(password, 10);



    const resultado = await db.query(

      `

      INSERT INTO usuarios

        (nombre, apellido, email, password_hash, telefono)

      VALUES

        ($1, $2, $3, $4, $5)

      RETURNING

        id,

        nombre,

        apellido,

        email,

        telefono,

        fecha_creacion

      `,

      [

        nombre,

        apellido || null,

        email,

        passwordHash,

        telefono || null

      ]

    );



    res.status(201).json({

      mensaje: "Usuario registrado correctamente",

      usuario: resultado.rows[0]

    });



  } catch (error) {



    if (error.code === "23505") {

      return res.status(409).json({

        mensaje: "El correo electrÃ³nico ya estÃ¡ registrado"

      });

    }



    console.error(error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.post("/api/login", async (req, res) => {

  try {

    const { email, password } = req.body;



    if (!email || !password) {

      return res.status(400).json({

        mensaje: "Email y password son obligatorios"

      });

    }



    const resultado = await db.query(

      `

      SELECT

        id,

        nombre,

        apellido,

        email,

        telefono,

        password_hash

      FROM usuarios

      WHERE email = $1

      `,

      [email]

    );



    if (resultado.rows.length === 0) {

      return res.status(401).json({

        mensaje: "Correo o contraseÃ±a incorrectos"

      });

    }



    const usuario = resultado.rows[0];



    const passwordCorrecto = await bcrypt.compare(

      password,

      usuario.password_hash

    );



    if (!passwordCorrecto) {

      return res.status(401).json({

        mensaje: "Correo o contraseÃ±a incorrectos"

      });

    }



    const token = jwt.sign(

      {

        id: usuario.id,

        email: usuario.email

      },

      process.env.JWT_SECRET,

      {

        expiresIn: "24h"

      }

    );



    res.json({

      mensaje: "Inicio de sesiÃ³n correcto",

      token: token,

      usuario: {

        id: usuario.id,

        nombre: usuario.nombre,

        apellido: usuario.apellido,

        email: usuario.email,

        telefono: usuario.telefono

      }

    });



  } catch (error) {

    console.error("Error en login:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});


// ======================================================
// PERFIL DEL USUARIO AUTENTICADO
// ======================================================

app.get("/api/perfil", verificarToken, async (req, res) => {
  try {
    const resultado = await db.query(
      `
        SELECT
          id,
          nombre,
          apellido,
          email,
          telefono,
          fecha_creacion
        FROM usuarios
        WHERE id = $1
      `,
      [req.usuario.id]
    );

    if (resultado.rows.length === 0) {
      return res.status(404).json({
        mensaje: "Usuario no encontrado"
      });
    }

    res.json({
      usuario: resultado.rows[0]
    });

  } catch (error) {
    console.error("Error al consultar perfil:", error);

    res.status(500).json({
      mensaje: "Error interno del servidor"
    });
  }
});

app.post("/api/mascotas", verificarToken, async (req, res) => {

  try {

    const {

      nombre,

      especie,

      raza,

      sexo,

      fecha_nacimiento,

      color,

      senas_particulares,

      foto_url

    } = req.body;



    if (!nombre || !especie) {

      return res.status(400).json({

        mensaje: "Nombre y especie son obligatorios"

      });

    }



    const resultado = await db.query(

      `

      INSERT INTO mascotas (

        usuario_id,

        nombre,

        especie,

        raza,

        sexo,

        fecha_nacimiento,

        color,

        senas_particulares,

        foto_url

      )

      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)

      RETURNING *

      `,

      [

        req.usuario.id,

        nombre,

        especie,

        raza || null,

        sexo || null,

        fecha_nacimiento || null,

        color || null,

        senas_particulares || null,

        foto_url || null

      ]

    );



    res.status(201).json({

      mensaje: "Mascota registrada correctamente",

      mascota: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al registrar mascota:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/api/mascotas", verificarToken, async (req, res) => {

  try {

    const resultado = await db.query(

      `

      SELECT

        id,

        nombre,

        especie,

        raza,

        sexo,

        fecha_nacimiento,

        color,

        senas_particulares,

        foto_url,

        modo_extravio,

        fecha_creacion,

        fecha_actualizacion

      FROM mascotas

      WHERE usuario_id = $1

      ORDER BY id DESC

      `,

      [req.usuario.id]

    );



    res.json({

      total: resultado.rows.length,

      mascotas: resultado.rows

    });



  } catch (error) {

    console.error("Error al consultar mascotas:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/api/mascotas/:id", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    const resultado = await db.query(

      `

      SELECT

        id,

        nombre,

        especie,

        raza,

        sexo,

        fecha_nacimiento,

        color,

        senas_particulares,

        foto_url,

        modo_extravio,

        fecha_creacion,

        fecha_actualizacion

      FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      `,

      [mascotaId, req.usuario.id]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    res.json({

      mascota: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al consultar mascota:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.put("/api/mascotas/:id", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    const {

      nombre,

      especie,

      raza,

      sexo,

      fecha_nacimiento,

      color,

      senas_particulares,

      foto_url

    } = req.body;



    if (!nombre || !especie) {

      return res.status(400).json({

        mensaje: "Nombre y especie son obligatorios"

      });

    }



    const resultado = await db.query(

      `

      UPDATE mascotas

      SET

        nombre = $1,

        especie = $2,

        raza = $3,

        sexo = $4,

        fecha_nacimiento = $5,

        color = $6,

        senas_particulares = $7,

        foto_url = $8,

        fecha_actualizacion = CURRENT_TIMESTAMP

      WHERE id = $9

        AND usuario_id = $10

      RETURNING *

      `,

      [

        nombre,

        especie,

        raza || null,

        sexo || null,

        fecha_nacimiento || null,

        color || null,

        senas_particulares || null,

        foto_url || null,

        mascotaId,

        req.usuario.id

      ]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    res.json({

      mensaje: "Mascota actualizada correctamente",

      mascota: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al actualizar mascota:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.delete("/api/mascotas/:id", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    const resultado = await db.query(

      `

      DELETE FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      RETURNING id, nombre

      `,

      [mascotaId, req.usuario.id]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    res.json({

      mensaje: "Mascota eliminada correctamente",

      mascota: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al eliminar mascota:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});


// ======================================================
// MODO EXTRAVÍO POR MASCOTA
// ======================================================

app.put("/api/mascotas/:id/extravio", verificarToken, async (req, res) => {
  const client = await db.connect();

  try {
    const mascotaId = req.params.id;
    const { extraviada } = req.body;

    if (typeof extraviada !== "boolean") {
      return res.status(400).json({
        mensaje: "El campo extraviada debe ser true o false"
      });
    }

    await client.query("BEGIN");

    const resultado = await client.query(
      `
        UPDATE mascotas
        SET
          modo_extravio = $1,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $2
          AND usuario_id = $3
        RETURNING *
      `,
      [
        extraviada,
        mascotaId,
        req.usuario.id
      ]
    );

    if (resultado.rows.length === 0) {
      await client.query("ROLLBACK");

      return res.status(404).json({
        mensaje: "Mascota no encontrada"
      });
    }

    await client.query(
      `
        UPDATE dispositivos
        SET
          modo = $1,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE mascota_id = $2
      `,
      [
        extraviada ? "extravio" : "normal",
        mascotaId
      ]
    );

    await client.query(
      `
        INSERT INTO eventos (
          mascota_id,
          tipo,
          origen,
          descripcion,
          datos
        )
        VALUES (
          $1,
          'MODO_EXTRAVIO',
          'APP',
          $2,
          $3::jsonb
        )
      `,
      [
        mascotaId,
        extraviada
          ? "Se activó el modo extravío desde la aplicación"
          : "Se desactivó el modo extravío desde la aplicación",
        JSON.stringify({
          extraviada
        })
      ]
    );

    await client.query("COMMIT");

    res.json({
      mensaje: extraviada
        ? "Modo extravío activado correctamente"
        : "Modo extravío desactivado correctamente",
      mascota: resultado.rows[0]
    });

  } catch (error) {
    await client.query("ROLLBACK");

    console.error("Error al cambiar modo extravío:", error);

    res.status(500).json({
      mensaje: "Error interno del servidor"
    });

  } finally {
    client.release();
  }
});

app.post("/api/dispositivos", verificarToken, async (req, res) => {

  try {

    const {

      mascota_id,

      device_uid,

      modelo

    } = req.body;



    if (!mascota_id || !device_uid) {

      return res.status(400).json({

        mensaje: "mascota_id y device_uid son obligatorios"

      });

    }



    // Verificar que la mascota pertenece al usuario autenticado

    const mascota = await db.query(

      `

      SELECT id, nombre

      FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      `,

      [mascota_id, req.usuario.id]

    );



    if (mascota.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    const resultado = await db.query(

      `

      INSERT INTO dispositivos (

        mascota_id,

        device_uid,

        modelo,

        estado,

        modo

      )

      VALUES ($1, $2, $3, 'activo', 'normal')

      RETURNING *

      `,

      [

        mascota_id,

        device_uid,

        modelo || null

      ]

    );



    res.status(201).json({

      mensaje: "Dispositivo registrado correctamente",

      dispositivo: resultado.rows[0]

    });



  } catch (error) {



    if (error.code === "23505") {

      return res.status(409).json({

        mensaje: "La mascota ya tiene un dispositivo o el device_uid ya existe"

      });

    }



    console.error("Error al registrar dispositivo:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.post("/api/device/:deviceUid/location", async (req, res) => {

  const client = await db.connect();



  try {

    const deviceKey = req.headers["x-device-key"];



    if (!deviceKey || deviceKey !== process.env.DEVICE_API_KEY) {

      return res.status(401).json({

        mensaje: "Dispositivo no autorizado"

      });

    }



    const deviceUid = req.params.deviceUid;



    const {

      latitude,

      longitude,

      altitude,

      accuracy,

      battery,

      mode,

      gps_timestamp

    } = req.body;



    const latitud = Number(latitude);

    const longitud = Number(longitude);



    if (

      !Number.isFinite(latitud) ||

      !Number.isFinite(longitud)

    ) {

      return res.status(400).json({

        mensaje: "Latitude y longitude son obligatorios"

      });

    }



    if (latitud < -90 || latitud > 90) {

      return res.status(400).json({

        mensaje: "Latitud invÃ¡lida"

      });

    }



    if (longitud < -180 || longitud > 180) {

      return res.status(400).json({

        mensaje: "Longitud invÃ¡lida"

      });

    }



    if (

      battery !== undefined &&

      (Number(battery) < 0 || Number(battery) > 100)

    ) {

      return res.status(400).json({

        mensaje: "Porcentaje de baterÃ­a invÃ¡lido"

      });

    }



    await client.query("BEGIN");



    const dispositivo = await client.query(

      `

      SELECT id, mascota_id, device_uid, modo
      FROM dispositivos
      WHERE device_uid = $1
        AND estado = 'activo'

      `,

      [deviceUid]

    );



    if (dispositivo.rows.length === 0) {

      await client.query("ROLLBACK");



      return res.status(404).json({

        mensaje: "Dispositivo no encontrado"

      });

    }



    const dispositivoId = dispositivo.rows[0].id;



    const ubicacion = await client.query(

      `

      INSERT INTO ubicaciones (

        dispositivo_id,

        latitud,

        longitud,

        altitud,

        precision_metros,

        bateria_porcentaje,

        modo,

        fecha_gps

      )

      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)

      RETURNING *

      `,

      [

        dispositivoId,

        latitud,

        longitud,

        altitude ?? null,

        accuracy ?? null,

        battery ?? null,
        dispositivo.rows[0].modo || "normal",
        gps_timestamp || null

      ]

    );



    await client.query(
      `
        UPDATE dispositivos
        SET
          bateria_porcentaje = COALESCE($1, bateria_porcentaje),
          ultima_conexion = CURRENT_TIMESTAMP,
          fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id = $2
      `,
      [
        battery ?? null,
        dispositivoId
      ]
    );



    await client.query("COMMIT");



    res.status(201).json({

      mensaje: "UbicaciÃ³n recibida correctamente",

      device_uid: deviceUid,

      ubicacion: ubicacion.rows[0]

    });



  } catch (error) {

    await client.query("ROLLBACK");



    console.error("Error al recibir ubicaciÃ³n:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });



  } finally {

    client.release();

  }

});

app.get("/api/mascotas/:id/ultima-ubicacion", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    const resultado = await db.query(

      `

      SELECT

        m.id AS mascota_id,

        m.nombre AS mascota_nombre,



        d.id AS dispositivo_id,

        d.device_uid,

        d.bateria_porcentaje,

        d.modo,

        d.ultima_conexion,



        u.latitud,

        u.longitud,

        u.altitud,

        u.precision_metros,

        u.fecha_gps,

        u.fecha_recepcion



      FROM mascotas m



      JOIN dispositivos d

        ON d.mascota_id = m.id



      LEFT JOIN LATERAL (

        SELECT *

        FROM ubicaciones

        WHERE dispositivo_id = d.id

        ORDER BY fecha_recepcion DESC

        LIMIT 1

      ) u ON TRUE



      WHERE m.id = $1

        AND m.usuario_id = $2

      `,

      [

        mascotaId,

        req.usuario.id

      ]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota o dispositivo no encontrado"

      });

    }



    const datos = resultado.rows[0];



    if (datos.latitud === null || datos.longitud === null) {

      return res.status(404).json({

        mensaje: "La mascota todavÃ­a no tiene ubicaciones registradas"

      });

    }



    res.json({

      mascota: {

        id: datos.mascota_id,

        nombre: datos.mascota_nombre

      },



      dispositivo: {

        id: datos.dispositivo_id,

        device_uid: datos.device_uid,

        bateria: datos.bateria_porcentaje,

        modo: datos.modo,

        ultima_conexion: datos.ultima_conexion

      },



      ubicacion: {

        latitud: datos.latitud,

        longitud: datos.longitud,

        altitud: datos.altitud,

        precision_metros: datos.precision_metros,

        fecha_gps: datos.fecha_gps,

        fecha_recepcion: datos.fecha_recepcion

      }

    });



  } catch (error) {

    console.error("Error al consultar Ãºltima ubicaciÃ³n:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.post("/api/device/:deviceUid/event", async (req, res) => {

  try {

    const deviceKey = req.headers["x-device-key"];



    if (!deviceKey || deviceKey !== process.env.DEVICE_API_KEY) {

      return res.status(401).json({

        mensaje: "Dispositivo no autorizado"

      });

    }



    const deviceUid = req.params.deviceUid;



    const {

      type,

      description,

      latitude,

      longitude,

      data,

      event_timestamp

    } = req.body;



    if (!type) {

      return res.status(400).json({

        mensaje: "El tipo de evento es obligatorio"

      });

    }



    // Buscar dispositivo y mascota asociada

    const dispositivo = await db.query(

      `

      SELECT

        d.id,

        d.device_uid,

        d.modo,

        d.mascota_id

      FROM dispositivos d

      WHERE d.device_uid = $1

        AND d.estado = 'activo'

      `,

      [deviceUid]

    );



    if (dispositivo.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Dispositivo no encontrado"

      });

    }



    const datosDispositivo = dispositivo.rows[0];



    // En mantenimiento no queremos generar falsas alertas de manipulaciÃ³n

    if (

      type === "MANIPULACION" &&

      datosDispositivo.modo === "mantenimiento"

    ) {

      return res.json({

        mensaje: "Evento ignorado por modo mantenimiento",

        device_uid: deviceUid

      });

    }



    const resultado = await db.query(

      `

      INSERT INTO eventos (

        mascota_id,

        dispositivo_id,

        tipo,

        origen,

        descripcion,

        latitud,

        longitud,

        datos,

        fecha_evento

      )

      VALUES (

        $1,

        $2,

        $3,

        'DISPOSITIVO',

        $4,

        $5,

        $6,

        $7::jsonb,

        $8

      )

      RETURNING *

      `,

      [

        datosDispositivo.mascota_id,

        datosDispositivo.id,

        type,

        description || null,

        latitude ?? null,

        longitude ?? null,

        JSON.stringify(data || {}),

        event_timestamp || null

      ]

    );



    res.status(201).json({

      mensaje: "Evento recibido correctamente",

      evento: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al registrar evento:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/api/mascotas/:id/eventos", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    // Verificar que la mascota pertenece al usuario

    const mascota = await db.query(

      `

      SELECT id, nombre

      FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      `,

      [mascotaId, req.usuario.id]

    );



    if (mascota.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    const resultado = await db.query(

      `

      SELECT

        id,

        tipo,

        origen,

        descripcion,

        latitud,

        longitud,

        datos,

        fecha_evento,

        fecha_recepcion

      FROM eventos

      WHERE mascota_id = $1

      ORDER BY fecha_recepcion DESC

      `,

      [mascotaId]

    );



    res.json({

      mascota: {

        id: mascota.rows[0].id,

        nombre: mascota.rows[0].nombre

      },

      total: resultado.rows.length,

      eventos: resultado.rows

    });



  } catch (error) {

    console.error("Error al consultar eventos:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.put("/api/dispositivos/:deviceUid/modo", verificarToken, async (req, res) => {

  const client = await db.connect();



  try {

    const deviceUid = req.params.deviceUid;

    const { modo } = req.body;



    const modosPermitidos = [

      "normal",

      "extravio",

      "mantenimiento"

    ];



    if (!modo || !modosPermitidos.includes(modo)) {

      return res.status(400).json({

        mensaje: "Modo invÃ¡lido",

        modosPermitidos

      });

    }



    await client.query("BEGIN");



    // Verificamos que el dispositivo pertenece

    // a una mascota del usuario autenticado.

    const dispositivo = await client.query(

      `

      SELECT

        d.id,

        d.device_uid,

        d.mascota_id,

        m.nombre AS mascota_nombre

      FROM dispositivos d

      JOIN mascotas m

        ON m.id = d.mascota_id

      WHERE d.device_uid = $1

        AND m.usuario_id = $2

      `,

      [

        deviceUid,

        req.usuario.id

      ]

    );



    if (dispositivo.rows.length === 0) {

      await client.query("ROLLBACK");



      return res.status(404).json({

        mensaje: "Dispositivo no encontrado"

      });

    }



    const datos = dispositivo.rows[0];



    await client.query(

      `

      UPDATE dispositivos

      SET

        modo = $1,

        fecha_actualizacion = CURRENT_TIMESTAMP

      WHERE id = $2

      `,

      [

        modo,

        datos.id

      ]

    );



    // Mantenemos sincronizado el estado de extravÃ­o de la mascota.

    await client.query(

      `

      UPDATE mascotas

      SET

        modo_extravio = $1,

        fecha_actualizacion = CURRENT_TIMESTAMP

      WHERE id = $2

      `,

      [

        modo === "extravio",

        datos.mascota_id

      ]

    );



    await client.query("COMMIT");



    res.json({

      mensaje: "Modo actualizado correctamente",

      dispositivo: {

        device_uid: datos.device_uid,

        mascota: datos.mascota_nombre,

        modo

      }

    });



  } catch (error) {

    await client.query("ROLLBACK");



    console.error("Error al cambiar modo:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });



  } finally {

    client.release();

  }

});

app.get("/api/device/:deviceUid/config", async (req, res) => {

  try {

    const deviceKey = req.headers["x-device-key"];



    if (!deviceKey || deviceKey !== process.env.DEVICE_API_KEY) {

      return res.status(401).json({

        mensaje: "Dispositivo no autorizado"

      });

    }



    const deviceUid = req.params.deviceUid;



    const resultado = await db.query(

      `

      SELECT

        device_uid,

        estado,

        modo,

        bateria_porcentaje

      FROM dispositivos

      WHERE device_uid = $1

        AND estado = 'activo'

      `,

      [deviceUid]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Dispositivo no encontrado"

      });

    }



    const dispositivo = resultado.rows[0];



    let intervaloUbicacion;



    switch (dispositivo.modo) {

      case "extravio":

        intervaloUbicacion = 30;

        break;



      case "mantenimiento":

        intervaloUbicacion = 900;

        break;



      default:

        intervaloUbicacion = 300;

    }



    res.json({

      device_uid: dispositivo.device_uid,

      modo: dispositivo.modo,

      intervalo_ubicacion_segundos: intervaloUbicacion,

      bateria: dispositivo.bateria_porcentaje

    });



  } catch (error) {

    console.error("Error al consultar configuraciÃ³n:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.post("/api/mascotas/:id/qr", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    // Comprobar que la mascota pertenece al usuario

    const mascota = await db.query(

      `

      SELECT id, nombre

      FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      `,

      [mascotaId, req.usuario.id]

    );



    if (mascota.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    // Revisar si ya tiene QR

    const qrExistente = await db.query(

      `

      SELECT token, activo

      FROM qr_tokens

      WHERE mascota_id = $1

      `,

      [mascotaId]

    );



    if (qrExistente.rows.length > 0) {

      return res.json({

        mensaje: "La mascota ya tiene un QR",

        mascota: mascota.rows[0],

        token: qrExistente.rows[0].token,

        activo: qrExistente.rows[0].activo

      });

    }



    // Generar token Ãºnico

    const token = crypto.randomUUID();



    const resultado = await db.query(

      `

      INSERT INTO qr_tokens (

        mascota_id,

        token,

        activo

      )

      VALUES ($1, $2, TRUE)

      RETURNING *

      `,

      [

        mascotaId,

        token

      ]

    );



    res.status(201).json({

      mensaje: "QR generado correctamente",

      mascota: mascota.rows[0],

      qr: resultado.rows[0]

    });



  } catch (error) {

    console.error("Error al generar QR:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/api/public/pet/:token", async (req, res) => {

  try {

    const token = req.params.token;



    const resultado = await db.query(

      `

      SELECT

        m.id AS mascota_id,

        m.nombre,

        m.especie,

        m.raza,

        m.sexo,

        m.color,

        m.senas_particulares,

        m.foto_url,

        m.modo_extravio,



        u.nombre AS propietario_nombre,

        u.telefono AS propietario_telefono,



        q.id AS qr_id,

        q.token



      FROM qr_tokens q



      JOIN mascotas m

        ON m.id = q.mascota_id



      JOIN usuarios u

        ON u.id = m.usuario_id



      WHERE q.token = $1

        AND q.activo = TRUE

      `,

      [token]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "QR no vÃ¡lido o desactivado"

      });

    }



    const datos = resultado.rows[0];



    // Registrar que alguien abriÃ³ el perfil mediante QR

    await db.query(

      `

      INSERT INTO eventos (

        mascota_id,

        tipo,

        origen,

        descripcion,

        datos

      )

      VALUES (

        $1,

        'QR_SCAN',

        'PUBLICO',

        'Se accediÃ³ al perfil pÃºblico mediante cÃ³digo QR',

        $2::jsonb

      )

      `,

      [

        datos.mascota_id,

        JSON.stringify({

          qr_token: datos.token

        })

      ]

    );



    res.json({

      mascota: {

        nombre: datos.nombre,

        especie: datos.especie,

        raza: datos.raza,

        sexo: datos.sexo,

        color: datos.color,

        senas_particulares: datos.senas_particulares,

        foto_url: datos.foto_url,

        extraviada: datos.modo_extravio

      },



      contacto: {

        nombre: datos.propietario_nombre,

        telefono: datos.propietario_telefono

      }

    });



  } catch (error) {

    console.error("Error en perfil pÃºblico:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/api/public/qr/:token.png", async (req, res) => {

  try {

    const token = req.params.token;



    const resultado = await db.query(

      `

      SELECT

        q.token,

        q.activo,

        m.nombre

      FROM qr_tokens q

      JOIN mascotas m

        ON m.id = q.mascota_id

      WHERE q.token = $1

        AND q.activo = TRUE

      `,

      [token]

    );



    if (resultado.rows.length === 0) {

      return res.status(404).json({

        mensaje: "QR no vÃ¡lido o desactivado"

      });

    }



    const urlPublica =

  `${process.env.PUBLIC_BASE_URL}/p/${token}`;





    const imagenQR = await QRCode.toBuffer(urlPublica, {

      type: "png",

      width: 600,

      margin: 2,

      errorCorrectionLevel: "H"

    });



    res.setHeader("Content-Type", "image/png");

    res.setHeader(

      "Content-Disposition",

      `inline; filename="TAGGY-${resultado.rows[0].nombre}.png"`

    );



    res.send(imagenQR);



  } catch (error) {

    console.error("Error al generar imagen QR:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});

app.get("/p/:token", (req, res) => {

  res.sendFile(

    path.join(

      __dirname,

      "../taggy-public/index.html"

    )

  );

});

app.post("/api/public/pet/:token/sighting", async (req, res) => {

  const client = await db.connect();



  try {

    const token = req.params.token;



    const {

      nombre,

      telefono,

      mensaje,

      latitude,

      longitude,

      accuracy

    } = req.body;



    const latitud =

      latitude !== undefined && latitude !== null

        ? Number(latitude)

        : null;



    const longitud =

      longitude !== undefined && longitude !== null

        ? Number(longitude)

        : null;



    if (

      latitud !== null &&

      (!Number.isFinite(latitud) || latitud < -90 || latitud > 90)

    ) {

      return res.status(400).json({

        mensaje: "Latitud invÃ¡lida"

      });

    }



    if (

      longitud !== null &&

      (!Number.isFinite(longitud) || longitud < -180 || longitud > 180)

    ) {

      return res.status(400).json({

        mensaje: "Longitud invÃ¡lida"

      });

    }



    await client.query("BEGIN");



    // Buscar mascota por token QR

    const qr = await client.query(

      `

      SELECT

        q.mascota_id,

        m.nombre AS mascota_nombre

      FROM qr_tokens q

      JOIN mascotas m

        ON m.id = q.mascota_id

      WHERE q.token = $1

        AND q.activo = TRUE

      `,

      [token]

    );



    if (qr.rows.length === 0) {

      await client.query("ROLLBACK");



      return res.status(404).json({

        mensaje: "QR no vÃ¡lido o desactivado"

      });

    }



    const mascotaId = qr.rows[0].mascota_id;



    // Guardar avistamiento

    const resultado = await client.query(

      `

      INSERT INTO avistamientos (

        mascota_id,

        nombre_reportante,

        telefono_reportante,

        mensaje,

        latitud,

        longitud,

        precision_metros

      )

      VALUES ($1,$2,$3,$4,$5,$6,$7)

      RETURNING *

      `,

      [

        mascotaId,

        nombre || null,

        telefono || null,

        mensaje || null,

        latitud,

        longitud,

        accuracy ?? null

      ]

    );



    // Crear tambiÃ©n un evento para el propietario

    await client.query(

      `

      INSERT INTO eventos (

        mascota_id,

        tipo,

        origen,

        descripcion,

        latitud,

        longitud,

        datos

      )

      VALUES (

        $1,

        'AVISTAMIENTO',

        'PUBLICO',

        'Se reportÃ³ un posible avistamiento de la mascota',

        $2,

        $3,

        $4::jsonb

      )

      `,

      [

        mascotaId,

        latitud,

        longitud,

        JSON.stringify({

          nombre_reportante: nombre || null,

          telefono_reportante: telefono || null,

          mensaje: mensaje || null

        })

      ]

    );



    await client.query("COMMIT");



    res.status(201).json({

      mensaje: "Avistamiento reportado correctamente",

      mascota: qr.rows[0].mascota_nombre,

      avistamiento: resultado.rows[0]

    });



  } catch (error) {

    await client.query("ROLLBACK");



    console.error("Error al reportar avistamiento:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });



  } finally {

    client.release();

  }

});

app.get("/api/mascotas/:id/avistamientos", verificarToken, async (req, res) => {

  try {

    const mascotaId = req.params.id;



    const mascota = await db.query(

      `

      SELECT id, nombre

      FROM mascotas

      WHERE id = $1

        AND usuario_id = $2

      `,

      [mascotaId, req.usuario.id]

    );



    if (mascota.rows.length === 0) {

      return res.status(404).json({

        mensaje: "Mascota no encontrada"

      });

    }



    const resultado = await db.query(

      `

      SELECT

        id,

        nombre_reportante,

        telefono_reportante,

        mensaje,

        latitud,

        longitud,

        precision_metros,

        fecha_avistamiento

      FROM avistamientos

      WHERE mascota_id = $1

      ORDER BY fecha_avistamiento DESC

      `,

      [mascotaId]

    );



  const avistamientosConMapa = resultado.rows.map((avistamiento) => {



  let mapa_url = null;



  if (

    avistamiento.latitud !== null &&

    avistamiento.longitud !== null

  ) {

    mapa_url =

      `https://www.google.com/maps?q=${avistamiento.latitud},${avistamiento.longitud}`;

  }



  return {

    ...avistamiento,

    mapa_url

  };

});



res.json({

  mascota: {

    id: mascota.rows[0].id,

    nombre: mascota.rows[0].nombre

  },



  total: avistamientosConMapa.length,



  avistamientos: avistamientosConMapa

});

  } catch (error) {

    console.error("Error al consultar avistamientos:", error);



    res.status(500).json({

      mensaje: "Error interno del servidor"

    });

  }

});


// ======================================================
// PUSH - CLAVE PUBLICA
// ======================================================

app.get("/api/push/public-key", (req, res) => {
  if (!process.env.VAPID_PUBLIC_KEY) {
    return res.status(503).json({
      mensaje: "Web Push no configurado"
    });
  }

  res.json({
    publicKey: process.env.VAPID_PUBLIC_KEY
  });
});

// ======================================================
// PUSH - REGISTRAR SUSCRIPCION
// ======================================================

app.post(
  "/api/push/subscribe",
  verificarToken,
  async (req, res) => {
    try {
      const {
        endpoint,
        keys,
        plataforma,
        user_agent
      } = req.body;

      if (
        !endpoint ||
        !keys ||
        !keys.p256dh ||
        !keys.auth
      ) {
        return res.status(400).json({
          mensaje: "Suscripción Push incompleta"
        });
      }

      const resultado = await db.query(
        `
          INSERT INTO push_suscripciones (
            usuario_id,
            endpoint,
            p256dh,
            auth,
            plataforma,
            user_agent,
            activa,
            fecha_actualizacion
          )
          VALUES (
            $1,$2,$3,$4,$5,$6,TRUE,CURRENT_TIMESTAMP
          )
          ON CONFLICT (endpoint)
          DO UPDATE SET
            usuario_id = EXCLUDED.usuario_id,
            p256dh = EXCLUDED.p256dh,
            auth = EXCLUDED.auth,
            plataforma = EXCLUDED.plataforma,
            user_agent = EXCLUDED.user_agent,
            activa = TRUE,
            fecha_actualizacion = CURRENT_TIMESTAMP
          RETURNING id
        `,
        [
          req.usuario.id,
          endpoint,
          keys.p256dh,
          keys.auth,
          plataforma || "web",
          user_agent || null
        ]
      );

      res.status(201).json({
        mensaje: "Notificaciones activadas",
        suscripcion_id: resultado.rows[0].id
      });

    } catch (error) {
      console.error(
        "Error registrando Push:",
        error
      );

      res.status(500).json({
        mensaje: "Error interno del servidor"
      });
    }
  }
);

// ======================================================
// PUSH - PRUEBA
// ======================================================

app.post(
  "/api/push/test",
  verificarToken,
  async (req, res) => {
    try {
      const resultado =
        await enviarPushUsuario(
          req.usuario.id,
          {
            title: "TAGGY",
            body: "Las notificaciones funcionan correctamente 🐾",
            url: "/TAGGYBACKEND/"
          }
        );

      res.json({
        mensaje: "Prueba Push procesada",
        ...resultado
      });

    } catch (error) {
      console.error(
        "Error en Push de prueba:",
        error
      );

      res.status(500).json({
        mensaje: "Error interno del servidor"
      });
    }
  }
);

app.listen(PORT, "0.0.0.0", () => {

  console.log(`Servidor TAGGY funcionando en puerto ${PORT}`);

  console.log(`Acceso local: http://localhost:${PORT}`);

  console.log(`Acceso pÃºblico configurado: ${process.env.PUBLIC_BASE_URL}`);

});
