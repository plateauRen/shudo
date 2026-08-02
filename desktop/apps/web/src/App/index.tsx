import { ChatPage, EndpointCategory, WKApp, Menus } from '@tsdaodao/base';
import { ContactsList } from '@tsdaodao/contacts';
import React from 'react';
import './index.css';
import AppLayout from '../Layout';
import { WKSDK } from 'wukongimjssdk';

const themeIconStyle: React.CSSProperties = { color: 'var(--wk-color-theme)', display: 'block' };

function HomeTabSelectedIcon() {
  return (
    <svg width="26" height="26" viewBox="0 0 26 26" style={themeIconStyle} aria-label="会话">
      <path d="M13.5,25 C19.8512746,25 25,19.8512746 25,13.5 C25,7.14872538 19.8512746,2 13.5,2 C7.14872538,2 2,7.14872538 2,13.5 C2,15.073038 2.31583219,16.5723095 2.88754349,17.9378613 C3.13929263,18.5391727 3.01561889,22.8206752 3.62073765,23.4225978 C4.2099763,24.0087241 8.47546922,23.8685633 9.08799349,24.1232438 C10.4466062,24.6881394 11.9368836,25 13.5,25 Z" fill="currentColor" />
      <path d="M10.8461538,16.1538462 C10.8461538,17.6195249 12.0343212,18.8076923 13.5,18.8076923 C14.9656788,18.8076923 16.1538462,17.6195249 16.1538462,16.1538462" stroke="#FFFFFF" strokeWidth="2" opacity="0.8" strokeLinecap="round" strokeLinejoin="round" fill="none" />
    </svg>
  );
}

function ContactsTabSelectedIcon() {
  return (
    <svg width="26" height="26" viewBox="0 0 26 26" style={themeIconStyle} aria-label="通讯录">
      <path d="M22.1153846,2 C23.2199541,2 24.1153846,2.8954305 24.1153846,4 L24.1153846,23 C24.1153846,24.1045695 23.2199541,25 22.1153846,25 L6.88461538,25 C5.78004588,25 4.88461538,24.1045695 4.88461538,23 L4.884,20.208 L2.95833333,20.2083333 C2.42906045,20.2083333 2,19.7792729 2,19.25 C2,18.7207271 2.42906045,18.2916667 2.95833333,18.2916667 L4.884,18.291 L4.884,14.458 L2.95833333,14.4583333 C2.42906045,14.4583333 2,14.0292729 2,13.5 C2,12.9707271 2.42906045,12.5416667 2.95833333,12.5416667 L4.884,12.541 L4.884,8.708 L2.95833333,8.70833333 C2.42906045,8.70833333 2,8.27927289 2,7.75 C2,7.22072711 2.42906045,6.79166667 2.95833333,6.79166667 L4.884,6.791 L4.88461538,4 C4.88461538,2.8954305 5.78004588,2 6.88461538,2 L22.1153846,2 Z" fill="currentColor" />
      <rect fill="#FFFFFF" opacity="0.8" x="17.0384615" y="8.19230769" width="1.76923077" height="10.6153846" rx="0.884615385" />
    </svg>
  );
}

function App() {
  registerMenus()
  return (
    <AppLayout />
  );
}

async function registerMenus() {

  WKSDK.shared().conversationManager.addConversationListener(() => {
    WKApp.menus.refresh()
  })

  WKApp.endpointManager.setMethod("menus.friendapply.change", () => {
    WKApp.menus.refresh()
  }, {
    category: EndpointCategory.friendApplyDataChange,
  })

  WKApp.menus.register("chat", (_context) => {
    const m = new Menus("chat", "/", "会话",
      <img alt='会话' src={require("./assets/HomeTab.svg").default}></img>,
      <HomeTabSelectedIcon />)
    let badge = 0;

    for (const conversation of WKSDK.shared().conversationManager.conversations) {
      badge += conversation.unread
    }

    m.badge = badge;

    if ((window as any).__POWERED_ELECTRON__) {
      (window as any).ipc.send("conversation-anager-unread-count", badge);
    }

    return m
  }, 1000)

  // 获取好友未申请添加数量
  // let unreadCount = 0;
  if (WKApp.loginInfo.isLogined()) {
    WKApp.apiClient.get(`/user/reddot/friendApply`).then(res => {
      // unreadCount = res.count;
      WKApp.mittBus.emit('friend-applys-unread-count', res.count)
      WKApp.loginInfo.setStorageItem(`${WKApp.loginInfo.uid}-friend-applys-unread-count`, res.count)
      WKApp.menus.refresh();
    })
  }

  WKApp.menus.register("contacts", (param) => {
    const m = new Menus("contacts", "/contacts", "通讯录",
      <img alt='通讯录' src={require("./assets/ContactsTab.svg").default}></img>,
      <ContactsTabSelectedIcon />)
    m.badge = WKApp.shared.getFriendApplysUnreadCount();
    return m
  }, 4000)

  WKApp.route.register("/", () => {
    return <ChatPage></ChatPage>
  })

  WKApp.route.register("/contacts", () => {
    return <ContactsList></ContactsList>
  })

}

export default App;

