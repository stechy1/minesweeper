import { NgModule } from '@angular/core';
import { BrowserModule } from '@angular/platform-browser';
import { RouterModule, Routes, RouterLinkActive } from '@angular/router';

import { AppComponent } from "./app.component";
import { OverviewComponent } from "./overview/overview.component";
import { GameCardComponent } from "./overview/game-card/game-card.component";
import { NewComponent } from "./new/new.component";
import { GameComponent } from "./game/game.component";
import { FormsModule } from "@angular/forms";
import { MinesweeperService } from "./minesweeper.service";

const appRoutes: Routes = [
    {path: '', redirectTo: 'overview', pathMatch: 'full'},
    {path: 'overview', component: OverviewComponent},
    {path: 'new', component: NewComponent},
    {path: 'game', redirectTo: 'overview', pathMatch: 'full'},
    {path: 'game/:id', component: GameComponent}
];

@NgModule({
    declarations: [
        AppComponent,
        OverviewComponent,
        GameCardComponent,
        NewComponent,
        GameComponent
    ],
    imports: [
        BrowserModule,
        FormsModule,
        RouterModule.forRoot(appRoutes)
    ],
    providers: [
        MinesweeperService
    ],
    bootstrap: [
        AppComponent
    ]
})
export class AppModule {

}