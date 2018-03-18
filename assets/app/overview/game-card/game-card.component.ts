import {
    Component, ElementRef, EventEmitter, Input, OnInit, Output,
    ViewChild
} from '@angular/core';
import { Grid } from "../../drawing/grid";
import { Drawer } from "../../drawing/drawer";
import { MinesweeperService } from "../../minesweeper.service";

@Component({
    selector: 'app-game-card',
    templateUrl: './game-card.component.html',
    styleUrls: ['./game-card.component.css']
})
export class GameCardComponent implements OnInit {

    @ViewChild('game_canvas')
    private _canvas: ElementRef;
    private _grid: Grid;

    private _game: any;

    @Output() public onGameEnd: EventEmitter<void> = new EventEmitter<void>();

    constructor(private _service: MinesweeperService) {
    }

    _redrawCanvas(): void {
        this._grid.drawer.push();
        this._grid.showGrid();
        this._grid.drawer.pop();
    }

    ngOnInit(): void {
        const drawer = new Drawer(this._canvas.nativeElement.getContext('2d'));
        const sloupcu = this._game['sloupcu'];
        const radku = this._game['radku'];

        this._grid = new Grid(drawer, sloupcu, radku, 20);
        this._canvas.nativeElement.width = this._grid.canvasWidth;
        this._canvas.nativeElement.height = this._grid.canvasHeight;
        this._redrawCanvas();

        this._service.getGameData(this._game['id']).subscribe(data => {
            this._grid.loadPoints(data);
            if (data[0]['id_stav'] != 1) {
                this.onGameEnd.emit();
                return;
            }
            this._redrawCanvas();
        })

        console.log(this._game);
    }

    @Input()
    set game(game: any) {
        this._game = game;
    }

    get game(): any {
        return this._game;
    }
}