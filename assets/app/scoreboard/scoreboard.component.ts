import { Component, OnInit } from '@angular/core';
import { MinesweeperService } from "../minesweeper.service";
import { ActivatedRoute, Router } from "@angular/router";

@Component({
    selector: 'app-scoreboard',
    templateUrl: 'scoreboard.component.html',
    styleUrls: ['./scoreboard.component.css']
})

export class ScoreboardComponent implements OnInit {

    winners = [];
    loosers = [];

    fragment = 'winners';

    constructor(private _service: MinesweeperService, private _route: ActivatedRoute,
                private _router: Router) {
        this._route.fragment.subscribe(fragment => {
            if (!fragment) {
                this._router.navigate(['/scoreboard'], {relativeTo: this._route, fragment: 'winners'})
                return;
            }

            this.fragment = fragment;
        });
    }

    ngOnInit() {

        this._service.getWinners().then(data => {
            data.forEach(value => {
                this.winners.push(value);
            });
        });

        this._service.getLoosers().then(data => {
            data.forEach(value => {
                this.loosers.push(value);
            })
        });

    }
}