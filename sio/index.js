const {Client} = require('pg');

const settings = {
    user: 'petr',
    host: 'localhost',
    database: 'petr',
    password: '',
    port: 5432,
};

function handler(socket) {
    const client = new Client(settings);
    client.connect();
    socket.on('disconnect', () => {
        console.log('user disconnected');
        client.end();
    });

    function sendGameData(oblastId) {
        client.query('SELECT * FROM oblast_tisk WHERE id_oblasti = $1',
            [oblastId])
        .then(res => {
            socket.emit('game-data-done', res.rows);
        }).catch(err => {
            console.error(err);
        });
    }

    socket.on('dashboard', () => {
        client.query('SELECT * FROM rozehrane_hry')
        .then(res => {
            socket.emit('dashboard-done', res.rows);
        }).catch(err => {
            console.error(err);
        });
    });

    /**
     * data = {
   *    sloupcu: number,
   *    radku: number,
   *    min: number,
   *    obtiznost: string
   *  }
     */
    socket.on('new-game', data => {
        client.query(
            'INSERT INTO oblast (sloupcu, radku, min, obtiznost) VALUES ($1, $2, $3, $4)',
            [data['sloupcu'], data['radku'], data['min'], data['obtiznost']])
        .then(res => {
            client.query("SELECT currval('oblast_id_seq');")
            .then(res2 => {
                socket.emit('new-game-done', {id: res2.rows[0]['currval']});
            }).catch(err => {
                console.error(err);
            })
        }).catch(err => {
            console.error(err);
        });
    })

    /**
     * data = {
   *    oblastId: number
   *  }
     */
    socket.on('area-info', data => {
        client.query(
            'SELECT oblast.radku, oblast.sloupcu, oblast.min, oblast.obtiznost, (SELECT COUNT(mina.cas) FROM pole INNER JOIN mina ON mina.id_pole = pole.id WHERE pole.id_oblasti = $1) AS oznacenych_min FROM oblast WHERE id = $1',
            [data['oblastId']])
        .then(res => {
            socket.emit('area-info-done', res.rows[0]);
        }).catch(err => {
            console.error(err);
        });
    })

    /**
     * data = {
   *    oblastId: number
   *  }
     */
    socket.on('game-data', data => {
        sendGameData(data['oblastId']);
    });

    /**
     *  data = {
   *    oblastId: number,
   *    sloupecek: number,
   *    radek: number
   *  }
     */
    socket.on('tah', data => {
        client.query(
            'INSERT INTO tah SELECT pole.id as id_pole FROM pole WHERE pole.id_oblasti = $1 AND pole.x = $2 AND pole.y = $3',
            [data['oblastId'], data['sloupecek'], data['radek']])
        .then(res => {
            sendGameData(data['oblastId']);
        }).catch(err => {
            console.error(err);
            if (err.code === '23505') {
                socket.emit('error', 'Pole nelze znovu označit');
            }

            throw new Error(err);
        }).catch(err => {});
    });

    /**
     * data = {
   *    oblastId: number,
   *    sloupecek: number,
   *    radek: number,
   *    action: string = insert|delete
   *  }
     */
    socket.on('mine', data => {
        client.query(
            'INSERT INTO mina SELECT pole.id as id_pole FROM pole WHERE pole.id_oblasti = $1 AND pole.x = $2 and pole.y = $3',
            [data['oblastId'], data['sloupecek'], data['radek']])
        .then(res => {
            sendGameData(data['oblastId']);
        }).catch(err => {
            console.error(err);
        });

    });
}

module.exports = handler;