import { Injectable } from "@angular/core";

import * as io from 'socket.io-client';
import { Observable } from "rxjs/Observable";

@Injectable()
export class MinesweeperService {

    private _url: string = 'http://localhost:3000';
    private _socket: any;

    constructor() {
        this._socket = io(this._url);
    }

    playableGames(): Observable<void> {
        return new Observable<void>(observer => {
            this._socket.on('dashboard-done', data => {
                observer.next(data);
            });
            this._socket.emit('dashboard');
        });
    }

    createNewGame(gameConfiguration: any): Promise<void> {
        return new Promise<void>(resolve => {
            this._socket.on('new-game-done', data => {
                resolve(data.id);
            })
            this._socket.emit('new-game', gameConfiguration);
        });
    }

    getAreaInfo(oblastId: number): Promise<void> {
        return new Promise<void>(resolve => {
            this._socket.on('area-info-done', data => {
                resolve(data);
            });
            this._socket.emit('area-info', {oblastId: oblastId});
        })
    }

    getGameData(oblastId: number): Observable<Array<any>> {
        return new Observable<Array<any>>(observer => {
            this._socket.on('game-data-done', data => {
                observer.next(data);
            });

            this._socket.emit('game-data', {oblastId: oblastId});
        });

    }

    markEmpty(oblastId: number, sloupecek: number, radek: number): void {
        this._socket.emit('tah', {oblastId: oblastId, sloupecek: sloupecek, radek: radek});
    }

    toggleMine(oblastId: number, sloupecek: number, radek: number): void {
        this._socket.emit('mine', {oblastId: oblastId, sloupecek: sloupecek, radek: radek});
    }

    errorListener(): Observable<void> {
        return new Observable<void>(observer => {
            this._socket.on('error', data => {
                observer.next(data);
            });
        });
    }
}