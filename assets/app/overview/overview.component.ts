import { Component, OnDestroy, OnInit } from '@angular/core';
import { MinesweeperService } from "../minesweeper.service";
import { Title } from "@angular/platform-browser";

@Component({
    selector: 'app-overview',
    templateUrl: './overview.component.html',
    styleUrls: ['./overview.component.css']
})
export class OverviewComponent implements OnInit, OnDestroy {

    public games = [];

    constructor(private _service: MinesweeperService, private _title: Title) {
    }

    ngOnInit(): void {
        this._title.setTitle("Hledání min");
        this._service.playableGames().subscribe((rows: any) => {
            this.games = this.games.concat(rows);
        });
    }

    ngOnDestroy(): void {
        this.games = [];
    }

    handleClear(): void {
        this._service.clearGames();
        this.games = [];
    }

    handleGameEnd(oblastId: number) {
        const index = this.games.map(game => game.id).indexOf(oblastId);
        this.games.splice(index, 1);
    }
}