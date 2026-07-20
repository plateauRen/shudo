import React from 'react';
import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
import reportWebVitals from './reportWebVitals';
import  { BaseModule, WKApp } from '@tsdaodao/base';
import  { LoginModule } from '@tsdaodao/login';
import  { DataSourceModule } from '@tsdaodao/datasource';
import {ContactsModule} from '@tsdaodao/contacts';

// Local self-hosted stack by default; override with REACT_APP_API_URL
const apiURL =
  process.env.REACT_APP_API_URL ||
  "http://127.0.0.1:8090/v1/"

if((window as any).__TAURI_IPC__) { // tauri环境
  console.log("tauri环境")
  WKApp.apiClient.config.apiURL = apiURL
}else if((window as any)?.__POWERED_ELECTRON__){
  console.log("__POWERED_ELECTRON__环境")
  WKApp.apiClient.config.apiURL = apiURL
}else{
  if(process.env.NODE_ENV === "development") {
    WKApp.apiClient.config.apiURL = apiURL
  }else {
    WKApp.apiClient.config.apiURL = process.env.REACT_APP_API_URL || "/api/v1/"
  }
}


WKApp.apiClient.config.tokenCallback = ()=> {
  return WKApp.loginInfo.token
}
WKApp.config.appVersion = `${process.env.REACT_APP_VERSION || "0.0.0"}`

WKApp.loginInfo.load() // 加载登录信息

WKApp.shared.registerModule(new BaseModule()); // 基础模块
WKApp.shared.registerModule(new DataSourceModule()) // 数据源模块
WKApp.shared.registerModule(new LoginModule()); // 登录模块
WKApp.shared.registerModule(new ContactsModule()); // 联系模块

WKApp.shared.startup() // app启动

// Initialize Electron notification bridge if running in Electron


ReactDOM.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
  document.getElementById('root')
);
reportWebVitals();

