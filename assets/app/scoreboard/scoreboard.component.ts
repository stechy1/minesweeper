import { Component, OnInit } from '@angular/core';
import { MinesweeperService } from "../minesweeper.service";
import { ActivatedRoute, Router } from "@angular/router";
import { Title } from "@angular/platform-browser";

@Component({
    selector: 'app-scoreboard',
    templateUrl: 'scoreboard.component.html',
    styleUrls: ['./scoreboard.component.css']
})

export class ScoreboardComponent implements OnInit {

    winners = [];
    loosers = [];

    fragment = 'winners';

    private _translate = {
        'winners': 'výherci',
        'loosers': 'poražení'
    };

    constructor(private _service: MinesweeperService, private _route: ActivatedRoute,
                private _router: Router, private _title: Title) {
        this._route.fragment.subscribe(fragment => {
            if (!fragment) {
                this._router.navigate(['/scoreboard'], {relativeTo: this._route, fragment: 'winners'})
                return;
            }

            this._title.setTitle(`Hledání min - Výsledková listina - ${this._translate[fragment]}`);

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