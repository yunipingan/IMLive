package cn.pingweb;

/**
 * Created by Administrator on 2017/8/25.
 */
import javax.websocket.Session;

public class User {

    private String id;

    private Session session;

    public String getId() {

        return id;
    }

    public void setId(String id) {

        this.id = id;
    }

    public Session getSession() {

        return session;
    }

    public void setSession(Session session) {

        this.session = session;
    }
}
