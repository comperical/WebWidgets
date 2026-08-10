
package io.webwidgets.core; 


import java.io.*;
import java.util.*;

import javax.servlet.http.HttpServletRequest;

import net.danburfoot.shared.Util;
import net.danburfoot.shared.ArgMap;
import net.danburfoot.shared.TimeUtil.*;


public class LogCentral
{
    public enum LogOpCode
    {
        GroupAllowTransfer,

        CodeCreation,
        CallBackSuccess,
        EmailInfoUpdate,
        CallBackFailure;


    }

    private static String getMinimizedFlatForm(ArgMap argmap)
    {
        String fullrep = argmap.flatStringForm("\t");
        return fullrep.substring(0, Math.min(fullrep.length(), 2000));
    }


    static synchronized void genericLog(LogOpCode opcode, WidgetItem dbitem, String extra)
    {
        try {

            List<Object> tklist = Util.listify(
                opcode,
                ExactMoment.build().asLongBasicTs(TimeZoneEnum.EST),
                dbitem.theOwner,
                dbitem.theName,
                extra == null ? "" : extra.trim()
            );

            emitStandardLog(tklist);

        } catch (Exception ex) {

            Util.pferr("Exception on log processing!!!!\n");
            ex.printStackTrace();
        }
    }


    static synchronized void callBackSuccess(LiteTableInfo LTI, WidgetUser accessor, ArgMap innmap)
    {
        try {
            // The full representation could be massive, if the innmap contains a Blob!!
            // Normally we'd expect 2K to be enough for the full object
            String flatrep = getMinimizedFlatForm(innmap);

            List<Object> tklist = Util.listify(
                LogOpCode.CallBackSuccess,
                ExactMoment.build().asLongBasicTs(TimeZoneEnum.EST),
                LTI.dbTabPair._1.theOwner,
                LTI.dbTabPair._1.theName,
                LTI.dbTabPair._2,
                innmap.getStr("ajaxop", "?????"),
                innmap.getInt(CoreUtil.STANDARD_ID_COLUMN_NAME, -1),
                flatrep
            );

            emitStandardLog(tklist);

        } catch (Exception ex) {

            Util.pferr("Exception on log processing!!!!\n");
            ex.printStackTrace();
        }
    }


    static synchronized void callBackFailure(HttpServletRequest request, ArgMap outmap) 
    {

        try {

            // Re-extracting the innmap here
            ArgMap innmap = WebUtil.getArgMap(request);

            // Same issue here about length of the innmap, if it contains a BLOB
            String outrep = getMinimizedFlatForm(outmap);
            String innrep = getMinimizedFlatForm(innmap);

            // Intentionally doing this a bit out-of-order, since the outrep has a limited
            // number of fields while innrep could be very large.
            List<Object> tklist = Util.listify(
                LogOpCode.CallBackFailure,
                ExactMoment.build().asLongBasicTs(TimeZoneEnum.EST),
                outrep,
                innrep
            );

            emitStandardLog(tklist);

        } catch (Exception ex) {

            Util.pferr("Exception on log processing!!!!\n");
            ex.printStackTrace();
        }

    }

    // We do not want records with newlines to fill into 
    private static void emitStandardLog(List<Object> tklist)
    {
        String s = Util.join(tklist, "\t").replace("\n", " :NL: ");
        Util.pf("%s\n", s);
    }

}