import { Component, OnDestroy, OnInit } from '@angular/core';
import { MinesweeperService } from "../minesweeper.service";
import { Router } from "@angular/router";
import { Subscription } from "rxjs/Subscription";

@Component({
    selector: 'app-new',
    templateUrl: './new.component.html',
    styleUrls: ['./new.component.css']
})
export class NewComponent  implements OnInit, OnDestroy {

    private _errorSub: Subscription;

    public configuration: GameConfiguration = new GameConfiguration();
    public gameTypes = [
        'Začátečník',
        'Pokročilý',
        'Expert',
        'Vlastní',
    ];

    constructor(private _service: MinesweeperService, private _router: Router) {
    }

    ngOnInit(): void {
        this._errorSub = this._service.errorListener().subscribe(err => {
            console.log(err);
        });
    }

    ngOnDestroy(): void {
        this._errorSub.unsubscribe();
    }

    public handleCreateGame() {
        this._service.createNewGame(this.configuration.buildData()).then(id => {
            this._router.navigate(['/game', id]);
        })
    }
}

class GameConfiguration {
    private _cols: number = 0;
    private _rows: number = 0;
    private _mines: number = 0;
    private _selectedGameType: number = 0;
    private _radioChanged: boolean = false;

    private _rawTypes = [
        'zacatecnik',
        'pokrocily',
        'expert',
        'vlastni',
    ];

    buildData(): any {
        return {
            'obtiznost': this._rawTypes[this._selectedGameType],
            'sloupcu': this._cols,
            'radku': this._rows,
            'min': this._mines
        };
    }

    get cols(): number {
        return this._cols;
    }

    set cols(value: number) {
        this._cols = value;
    }

    get rows(): number {
        return this._rows;
    }

    set rows(value: number) {
        this._rows = value;
    }

    get mines(): number {
        return this._mines;
    }

    set mines(value: number) {
        this._mines = value;
    }

    get selectedGameType(): number {
        return this._selectedGameType;
    }

    set selectedGameType(value: number) {
        this._selectedGameType = value;
        this._radioChanged = true;
    }

    get radioChanged(): boolean {
        return this._radioChanged;
    }
}