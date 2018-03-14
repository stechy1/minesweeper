import { Component, OnDestroy, OnInit } from '@angular/core';
import { MinesweeperService } from "../minesweeper.service";

@Component({
    selector: 'app-overview',
    templateUrl: './overview.component.html',
    styleUrls: ['./overview.component.css']
})
export class OverviewComponent implements OnInit, OnDestroy {

    public games = [];

    constructor(private _service: MinesweeperService) {
    }


    ngOnInit(): void {
        this._service.playableGames().subscribe((rows: any) => {
            this.games = this.games.concat(rows);
        });
    }


    ngOnDestroy(): void {
        this.games = [];
    }
}