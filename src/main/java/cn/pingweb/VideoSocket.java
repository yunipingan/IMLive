package cn.pingweb;

/**
 * Created by Administrator on 2017/8/25.
 */
import java.io.IOException;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Set;

import javax.websocket.OnClose;
import javax.websocket.OnMessage;
import javax.websocket.OnOpen;
import javax.websocket.Session;
import javax.websocket.server.PathParam;
import javax.websocket.server.ServerEndpoint;

@ServerEndpoint("/video/{roomId}/{userId}")
public class VideoSocket {

    /**
     * 存放房间与用户
     */
    private static HashMap<String,Set<User>>  usersRoom = new HashMap<String,Set<User>>();

    /**
     * 打开websocket
     * @param session websocket的session
     * @param uid 打开用户的UID
     */
    @OnOpen
    public void onOpen(Session session, @PathParam("roomId")String roomId, @PathParam("userId")String userId) {
        Set<User> users = usersRoom.get(roomId);
        if(users== null ){
            users = new HashSet<User>();
        }
        if(users.size()>=2){
            sendMessage(session, "peopleMax");//目前只支持两个人之间的通讯 ,所以不能超过两个人
        }else{
            User user = new User();
            user.setId(userId);
            user.setSession(session);
            users.add(user);
            usersRoom.put(roomId,users);
        }
    }

    /**
     * websocket关闭
     * @param session 关闭的session
     * @param uid 关闭的用户标识
     */
    @OnClose
    public void onClose(Session session, @PathParam("roomId")String roomId, @PathParam("userId")String userId) {

        Set<User> users = usersRoom.get(roomId);
        if(users!=null){
            for (User user:users) {
                if(user.getId().equals(userId)){
                    users.remove(user);
                    return;
                }else if(!user.getId().equals(userId)){
                    sendMessage(user.getSession(), "bye");//退出之后,发送给另一个人信息,以便让他断开视频连接
                    return;
                }
            }
        }
    }

    /**
     * 收到消息
     * @param message 消息内容
     * @param session 发送消息的session
     * @param uid
     */
    @OnMessage
    public void onMessage(String message,Session session, @PathParam("roomId")String roomId, @PathParam("userId")String userId) {
        Set<User> users = usersRoom.get(roomId);
        if(users!=null){
            User recipient = null;
            for (User user:users) {//查询当前会议中另一个在线人
                if(!user.getId().equals(userId)){
                    recipient = user;
                }
            }
            if(message.startsWith("query-On-line")){//如果查询是否有人在线
                if(users.size()>1){
                    sendMessage(session,"query-On-line-Yes");
                }else{
                    sendMessage(session,"query-On-line-No");
                }
            }else if(recipient!=null){
                sendMessage(recipient.getSession(), message);
            }
        }
    }
    /**
     * 给客户端发送消息
     * @param session
     * @param message
     */
    public void sendMessage(Session session,String message){
        try {
            if(session.isOpen()) {
                session.getBasicRemote().sendText(new String(message));
            }
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
