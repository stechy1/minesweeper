import { Component, ElementRef, OnDestroy, OnInit, ViewChild } from '@angular/core';
import { ActivatedRoute, Router } from "@angular/router";
import { MinesweeperService } from "../minesweeper.service";
import { Subscription } from "rxjs/Subscription";
import { Drawer } from "../drawing/drawer";
import { Grid } from "../drawing/grid";
import { Title } from "@angular/platform-browser";

@Component({
    selector: 'app-game',
    templateUrl: './game.component.html',
    styleUrls: ['./game.component.css']
})
export class GameComponent implements OnInit, OnDestroy {

    private _routeSub: Subscription;
    private _gameDataSub: Subscription;
    private _errorSub: Subscription;

    @ViewChild('game_canvas')
    private _canvas: ElementRef;
    private _grid: Grid;
    private _areaId: number;
    private _minesCount: number;
    private _minesRemaining: number;
    private _dificulty: string;
    private _gameState: number = 0;

    constructor(private _service: MinesweeperService, private _route: ActivatedRoute,
                private _router: Router, private _title: Title) {
    }

    _mousePosRelative(event: MouseEvent): { x: number, y: number } {
        const rect = this._canvas.nativeElement.getBoundingClientRect();
        return {x: event.clientX - rect.left, y: event.clientY - rect.top};
    }

    _redrawCanvas(): void {
        this._grid.drawer.push();
        this._grid.showGrid();
        this._grid.drawer.pop();
    }

    ngOnInit(): void {
        const drawer = new Drawer(this._canvas.nativeElement.getContext('2d'));

        this._errorSub = this._service.errorListener().subscribe(err => {
            console.log(err);
        });

        this._routeSub = this._route.paramMap.subscribe(params => {
            this._areaId = +params.get('id');
            this._title.setTitle(`Hledání min - Hra č. ${this._areaId}`);
            this._service.getAreaInfo(this._areaId)
            .then(info => {
                const sloupcu = info['sloupcu'];
                const radku = info['radku'];
                this._minesCount = info['min'];
                this._dificulty = info['obtiznost'];

                this._grid = new Grid(drawer, sloupcu, radku, 20);
                this._canvas.nativeElement.width = this._grid.canvasWidth;
                this._canvas.nativeElement.height = this._grid.canvasHeight;
                this._redrawCanvas();

                this._gameDataSub = this._service.getGameData(this._areaId).subscribe(data => {
                    console.log(data);
                    this._gameState = data[0]['id_stav'];
                    this._grid.loadPoints(data);
                    this._redrawCanvas();
                });
            }).catch(() => {
                this._router.navigate([""]);
            });
        });
    }

    ngOnDestroy(): void {
        this._routeSub.unsubscribe();
        this._errorSub.unsubscribe();
        if (this._gameDataSub) {
            this._gameDataSub.unsubscribe();
        }
    }

    get gameState(): number {
        return this._gameState;
    }

    handleClick(e: MouseEvent): boolean {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            const point = this._grid.mouseToPoint(coord);
            this._service.markEmpty(this._areaId, point.col + 1, point.row + 1);
        }
        return false;
    }

    handleContextMenu(e: MouseEvent): boolean {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            const point = this._grid.mouseToPoint(coord);
            this._service.toggleMine(this._areaId, point.col + 1, point.row + 1);
        }
        return false;
    }

    handleMove(e: MouseEvent): void {
        const coord = this._mousePosRelative(e);
        if (this._grid.isMouseInGridmouse(coord)) {
            this._grid.highlighted = this._grid.mouseToPoint(coord);
            this._redrawCanvas();
        }
    }

    handleLeave(): void {
        this._grid.highlighted = null;
        this._redrawCanvas();
    }
}